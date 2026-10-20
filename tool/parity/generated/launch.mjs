// node_modules/@sayren/storefront-sdk/src/payments/launch.ts
var PG_SCRIPTS = {
  /** https://docs.tosspayments.com/sdk/v2/js */
  tosspayments: { src: "https://js.tosspayments.com/v2/standard", global: "TossPayments" },
  /** https://developers.portone.io/sdk/ko/v2-sdk/readme */
  portone: { src: "https://cdn.portone.io/v2/browser-sdk.js", global: "PortOne" },
  /** https://docs.pay.naver.com/docs/onetime-payment/payment/payment-auth-window */
  naverpay: { src: "https://nsp.pay.naver.com/sdk/js/naverpay.min.js", global: "Naver" }
};
var TOSS_CANCEL_CODES = /* @__PURE__ */ new Set(["USER_CANCEL", "PAY_PROCESS_CANCELED"]);
var PORTONE_CANCEL_CODES = /* @__PURE__ */ new Set([
  "PAY_PROCESS_CANCELED",
  "USER_CANCEL",
  "CANCELED_BY_USER",
  "FAILURE_TYPE_USER_CANCEL"
]);
var NAVERPAY_CANCEL_CODES = /* @__PURE__ */ new Set(["UserCancel"]);
function errorCode(error, fallback) {
  const code = error?.code;
  return typeof code === "string" && code ? code : fallback;
}
function errorMessage(error, fallback) {
  return error instanceof Error && error.message ? error.message : fallback;
}
function record(value) {
  return value && typeof value === "object" ? value : {};
}
function launchable(launch) {
  return ["tosspayments", "portone", "kakaopay", "naverpay", "paypal", "mock"].includes(
    launch.type
  );
}
var scriptFailure = (pg) => ({
  category: "PREPARE_FAILURE",
  code: "PG_SCRIPT_UNAVAILABLE",
  message: `${pg} 결제 스크립트를 불러오지 못했습니다`
});
async function launchPayment(launch, env) {
  const value = launch;
  switch (launch.type) {
    case "mock": {
      env.navigate(String(value.redirectUrl));
      return null;
    }
    case "kakaopay":
    case "paypal": {
      const urls = record(value.redirectUrl);
      const url = env.desktop() ? urls.pc ?? urls.mobile : urls.mobile ?? urls.pc;
      if (typeof url !== "string" || !url) {
        const kakao = value.type === "kakaopay";
        return {
          category: "PREPARE_FAILURE",
          code: kakao ? "KAKAOPAY_URL_MISSING" : "PAYPAL_URL_MISSING",
          message: kakao ? "카카오페이 결제창 주소가 없습니다" : "PayPal 결제창 주소가 없습니다"
        };
      }
      env.navigate(url);
      return null;
    }
    case "tosspayments": {
      let toss;
      try {
        toss = await env.loadScript(
          PG_SCRIPTS.tosspayments.src,
          PG_SCRIPTS.tosspayments.global
        );
      } catch {
        return scriptFailure("토스페이먼츠");
      }
      try {
        await toss(String(value.clientKey)).payment({ customerKey: toss.ANONYMOUS }).requestPayment(record(value.request));
        return null;
      } catch (error) {
        const code = errorCode(error, "TOSS_REQUEST_FAILED");
        return TOSS_CANCEL_CODES.has(code) ? { category: "USER_CANCELED", code, message: errorMessage(error, "결제를 취소했습니다") } : {
          category: "PREPARE_FAILURE",
          code,
          message: errorMessage(error, "결제창을 열지 못했습니다")
        };
      }
    }
    case "portone": {
      let portone;
      try {
        portone = await env.loadScript(
          PG_SCRIPTS.portone.src,
          PG_SCRIPTS.portone.global
        );
      } catch {
        return scriptFailure("포트원");
      }
      try {
        const response = await portone.requestPayment(record(value.request));
        if (response?.code) {
          return PORTONE_CANCEL_CODES.has(response.code) ? {
            category: "USER_CANCELED",
            code: response.code,
            message: response.message ?? "결제를 취소했습니다"
          } : {
            category: "PREPARE_FAILURE",
            code: response.code,
            message: response.message ?? "결제창을 열지 못했습니다"
          };
        }
        return null;
      } catch (error) {
        return {
          category: "PREPARE_FAILURE",
          code: errorCode(error, "PORTONE_REQUEST_FAILED"),
          message: errorMessage(error, "결제창을 열지 못했습니다")
        };
      }
    }
    case "naverpay": {
      let naver;
      try {
        naver = await env.loadScript(
          PG_SCRIPTS.naverpay.src,
          PG_SCRIPTS.naverpay.global
        );
      } catch {
        return scriptFailure("네이버페이");
      }
      try {
        naver.Pay.create(record(value.sdk)).open(record(value.request));
        return null;
      } catch (error) {
        return {
          category: "PREPARE_FAILURE",
          code: errorCode(error, "NAVERPAY_OPEN_FAILED"),
          message: errorMessage(error, "결제창을 열지 못했습니다")
        };
      }
    }
    default:
      return {
        category: "PREPARE_FAILURE",
        code: "UNSUPPORTED_LAUNCH",
        message: "지원하지 않는 결제창입니다"
      };
  }
}
function readPaymentReturn(params) {
  const get = (key) => params.get(key) ?? void 0;
  const paymentId = get("sayrenPaymentId") ?? null;
  const callbackToken = get("sayrenToken");
  const attemptId = get("sayrenAttemptId");
  if (!paymentId || !callbackToken || !attemptId) return { kind: "status", paymentId };
  const base = { paymentId, attemptId, callbackToken };
  const result = get("sayrenResult");
  const failure = (category, code, message) => ({
    kind: "failure",
    ...base,
    category,
    code: code.slice(0, 100),
    message: message.slice(0, 500)
  });
  switch (get("sayrenPg")) {
    case "portone": {
      const code = get("code");
      if (code) {
        const pgCode = get("pgCode");
        const canceled = PORTONE_CANCEL_CODES.has(code) || pgCode !== void 0 && PORTONE_CANCEL_CODES.has(pgCode);
        return failure(
          canceled ? "USER_CANCELED" : "DECLINED",
          pgCode ?? code,
          get("pgMessage") ?? get("message") ?? "결제에 실패했습니다"
        );
      }
      const txId = get("txId");
      return txId ? { kind: "confirm", ...base, pgToken: txId } : { kind: "status", paymentId };
    }
    case "kakaopay": {
      if (result === "cancel")
        return failure("USER_CANCELED", "USER_CANCEL", "결제를 취소했습니다");
      if (result === "fail") return failure("DECLINED", "KAKAOPAY_FAIL", "결제에 실패했습니다");
      const token = get("pg_token");
      return result === "success" && token ? { kind: "confirm", ...base, pgToken: token } : { kind: "status", paymentId };
    }
    case "naverpay": {
      const code = get("resultCode");
      if (!code) return { kind: "status", paymentId };
      if (code !== "Success") {
        return failure(
          NAVERPAY_CANCEL_CODES.has(code) ? "USER_CANCELED" : "DECLINED",
          code,
          get("resultMessage") ?? "결제에 실패했습니다"
        );
      }
      const naverPaymentId = get("paymentId");
      return naverPaymentId ? { kind: "confirm", ...base, pgToken: naverPaymentId } : { kind: "status", paymentId };
    }
    case "tosspayments": {
      if (result === "fail") {
        const code = get("code");
        if (!code) return { kind: "status", paymentId };
        return failure(
          TOSS_CANCEL_CODES.has(code) ? "USER_CANCELED" : "DECLINED",
          code,
          get("message") ?? "결제에 실패했습니다"
        );
      }
      const paymentKey = get("paymentKey");
      const amount = Number(get("amount"));
      if (result !== "success" || !paymentKey || !Number.isFinite(amount))
        return { kind: "status", paymentId };
      return { kind: "confirm", ...base, pgToken: paymentKey, amount };
    }
    default:
      return { kind: "status", paymentId };
  }
}
var RETURN_SECRET_PARAMS = [
  "sayrenToken",
  "sayrenAttemptId",
  "sayrenPg",
  "sayrenResult",
  "paymentKey",
  "orderId",
  "amount",
  "paymentId",
  "txId",
  "code",
  "message",
  "pgCode",
  "pgMessage",
  "pg_token",
  "resultCode",
  "resultMessage",
  "reserveId"
];
function scrubReturnUrl(url) {
  const target = new URL(url);
  for (const key of RETURN_SECRET_PARAMS) target.searchParams.delete(key);
  return target.toString();
}
export {
  PG_SCRIPTS,
  PORTONE_CANCEL_CODES,
  RETURN_SECRET_PARAMS,
  launchPayment,
  launchable,
  readPaymentReturn,
  scrubReturnUrl
};
