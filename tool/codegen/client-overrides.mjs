// 생성 규칙으로 옮길 수 없는 클라이언트 메서드의 Dart 구현.
// 키는 `{클라이언트 클래스}:{네임스페이스.메서드}`, ts는 Node 메서드 원문(공백 정리)이다. 원문이 바뀌면 생성기가 멈추므로 Dart 구현을 맞춰 고치고 ts를 바꾼다.
// dart는 시그니처와 본문, doc는 Node JSDoc이 없을 때의 문서다.

export const CLIENT_OVERRIDES = {
  "StoreClient:uploads.upload": {
    ts: "upload: async ( file: Blob, options?: { purpose?: UploadPurpose; filename?: string }, ): Promise<UploadTicket> => { const filename = options?.filename ?? (typeof File !== \"undefined\" && file instanceof File ? file.name : \"\"); if (!filename) { throw new ApiError(400, \"UPLOAD_FILENAME_REQUIRED\", \"파일명이 필요합니다\"); } if (file.size === 0) { // 빈 파일은 PUT 자체는 성공하고 0바이트 객체가 공개돼 깨진 이미지로 남는다 throw new ApiError(400, \"EMPTY_FILE\", `파일이 비어 있습니다: ${filename}`); } const purpose = options?.purpose ?? \"description\"; const rejection = uploadRejection(purpose, filename, file.size); if (rejection) { throw new ApiError(rejection.status, rejection.code, rejection.message); } const ticket = await storeHttp.request(\"POST\", \"/uploads\", uploadTicketSchema, { body: uploadRequestSchema.parse({ filename, purpose, size: file.size }), }); const put = await fetchFn(ticket.uploadUrl, { method: \"PUT\", // 발급 응답의 헤더를 함께 싣는다 — 판매 파일(이슈 #48)은 비공개 헤더가 빠지면 공개 객체가 된다 headers: { \"content-type\": file.type || \"application/octet-stream\" }, body: file, }); if (!put.ok) { throw new ApiError(put.status, \"UPLOAD_PUT_FAILED\", `업로드에 실패했습니다: ${filename}`); } return ticket; }",
    doc: "파일 하나를 올립니다. 자리 발급과 바이트 PUT을 한 번에 하고, 끝나면 `url`이 공개 주소입니다.\n\n용도 제한(확장자·크기)은 서버가 판정하지만, 같은 규칙으로 먼저 걸러 큰 파일을 보낸 뒤 거절되는 왕복을 없앱니다.\n파일 이름은 `filename`, 없으면 [XFile.name]입니다.",
    dart: `
  Future<UploadTicket> upload(XFile file, [({String? purpose, String? filename})? options]) async {
    final filename = options?.filename ?? file.name;
    if (filename.isEmpty) throw const ApiError(400, 'UPLOAD_FILENAME_REQUIRED', '파일명이 필요합니다');
    final size = await file.length();
    // 빈 파일은 PUT 자체는 성공하고 0바이트 객체가 공개돼 깨진 이미지로 남는다
    if (size == 0) throw ApiError(400, 'EMPTY_FILE', '파일이 비어 있습니다: $filename');
    final purpose = options?.purpose ?? 'description';
    final rejection = uploadRejection(purpose, filename, size);
    if (rejection != null) throw ApiError(rejection.status, rejection.code, rejection.message);
    final ticket = await _http.store.request('POST', '/uploads', uploadTicketSchema,
        RequestOptions(body: uploadRequestSchema.parse({'filename': filename, 'purpose': purpose, 'size': size}).toJson()));
    final mimeType = file.mimeType;
    final put = http.Request('PUT', Uri.parse(ticket.uploadUrl))
      ..headers['content-type'] = mimeType != null && mimeType.isNotEmpty ? mimeType : 'application/octet-stream'
      ..bodyBytes = await file.readAsBytes();
    final response = await _http.fetch(put);
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ApiError(response.statusCode, 'UPLOAD_PUT_FAILED', '업로드에 실패했습니다: $filename');
    }
    return ticket;
  }
`,
  },
  "StoreClient:products.setCalendar": {
    ts: "setCalendar: (productId: string, body: SetCalendarRequest) => storeHttp.request( \"PUT\", path`/products/${productId}/calendar`, z.object({ updated: z.number().int() }), { body: setCalendarRequestSchema.parse(body) }, )",
    doc: "`PUT /v1/products/{productId}/calendar` — 날짜별 재고·가격을 바꿉니다. 바뀐 날짜 수(`updated`)를 돌려줍니다.",
    dart: `
  Future<({int updated})> setCalendar(String productId, SetCalendarRequest body) async {
    final json = await _http.store.request('PUT', '/products/\${encodeURIComponent(productId)}/calendar',
        z.plainObject({'updated': z.number().int_()}), RequestOptions(body: setCalendarRequestSchema.parse(body).toJson()));
    return (updated: json['updated'] as int);
  }
`,
  },
  "StoreClient:categories.remove": {
    ts: "remove: (categoryId: string, opts?: { strategy?: CategoryDeleteStrategy }) => storeHttp.requestVoid(\"DELETE\", path`/categories/${categoryId}`, { query: (opts?.strategy ? { strategy: opts.strategy } : {}) as Query, })",
    doc: "`DELETE /v1/categories/{categoryId}` — [strategy]는 하위 카테고리·상품 처리 방식입니다.",
    dart: `
  Future<void> remove(String categoryId, {String? strategy}) async => _http.store.requestVoid(
      'DELETE', '/categories/\${encodeURIComponent(categoryId)}', RequestOptions(query: {if (truthy(strategy)) 'strategy': strategy}));
`,
  },
  "StoreClient:orderItems.cancelPreview": {
    ts: "cancelPreview: (orderItemId: string, quantity?: number) => storeHttp.request( \"GET\", path`/order-items/${orderItemId}/cancel-preview`, sellerCancelPreviewSchema, { query: (quantity ? { quantity } : {}) as Query }, )",
    doc: "`GET /v1/order-items/{orderItemId}/cancel-preview` — 셀러 취소의 환불 미리보기입니다. [quantity]를 주면 부분 취소입니다.",
    dart: `
  Future<SellerCancelPreview> cancelPreview(String orderItemId, [int? quantity]) async => _http.store.request(
      'GET', '/order-items/\${encodeURIComponent(orderItemId)}/cancel-preview', sellerCancelPreviewSchema,
      RequestOptions(query: {if (truthy(quantity)) 'quantity': quantity}));
`,
  },
  "StoreClient:orderItems.dispatchBulk": {
    ts: "dispatchBulk: ( dispatches: Array<{ orderItemId: string } & DispatchRequest>, idempotencyKey?: string, ) => storeHttp.request(\"POST\", \"/order-items/dispatch\", bulkResultSchema, { body: { dispatches }, headers: idempotency(idempotencyKey), })",
    doc: "`POST /v1/order-items/dispatch` — 여러 주문상품을 한 번에 발송 처리합니다. 항목마다 주문상품 id와 발송 정보([DispatchRequest])입니다.",
    dart: `
  Future<BulkResult> dispatchBulk(List<({String orderItemId, DispatchRequest dispatch})> dispatches,
          [String? idempotencyKey]) async =>
      _http.store.request('POST', '/order-items/dispatch', bulkResultSchema,
          RequestOptions(body: {
            'dispatches': [
              for (final d in dispatches) {'orderItemId': d.orderItemId, ...d.dispatch.toJson()},
            ],
          }, headers: _idempotency(idempotencyKey)));
`,
  },
  "StoreClient:orderItems.fulfillBulk": {
    ts: "fulfillBulk: (orderItemIds: string[], body: FulfillRequest = {}, idempotencyKey?: string) => storeHttp.request(\"POST\", \"/order-items/fulfill\", bulkResultSchema, { body: fulfillBulkRequestSchema.parse({ orderItemIds, ...body }), headers: idempotency(idempotencyKey), })",
    doc: "`POST /v1/order-items/fulfill` — 여러 주문상품을 한 번에 제공 처리합니다.",
    dart: `
  Future<BulkResult> fulfillBulk(List<String> orderItemIds, [FulfillRequest? body, String? idempotencyKey]) async =>
      _http.store.request('POST', '/order-items/fulfill', bulkResultSchema,
          RequestOptions(
              body: fulfillBulkRequestSchema.parse({'orderItemIds': orderItemIds, ...?body?.toJson()}).toJson(),
              headers: _idempotency(idempotencyKey)));
`,
  },
  "StoreClient:commerceFlows.saveDraft": {
    ts: "saveDraft: (flowId: string, body: SaveFlowDraftRequest, revision?: number) => storeHttp.request(\"PUT\", path`/commerce-flows/${flowId}/draft`, commerceFlowSchema, { body: saveFlowDraftRequestSchema.parse(body), headers: revision === undefined ? undefined : { \"if-match\": String(revision) }, })",
    doc: "`PUT /v1/commerce-flows/{flowId}/draft` — 초안을 저장합니다. [revision]을 주면 `If-Match`로 보내 그 사이 바뀌었으면 409입니다.",
    dart: `
  Future<CommerceFlow> saveDraft(String flowId, SaveFlowDraftRequest body, [int? revision]) async => _http.store.request(
      'PUT', '/commerce-flows/\${encodeURIComponent(flowId)}/draft', commerceFlowSchema,
      RequestOptions(
          body: saveFlowDraftRequestSchema.parse(body).toJson(),
          headers: revision == null ? null : {'if-match': '$revision'}));
`,
  },
  "StoreClient:claims.list": {
    ts: "list: (params?: ClaimListParams) => storeHttp.request(\"GET\", \"/claims\", pageSchema(claimSchema), { query: { ...params, status: Array.isArray(params?.status) ? params.status.join(\",\") : params?.status, } as Query, })",
    doc: "`GET /v1/claims` — 클레임 목록입니다. `status`에 목록을 주면 여러 상태를 한 번에 거릅니다.",
    dart: `
  Future<Page<Claim>> list([ClaimListParams? params]) async {
    final status = params?.status;
    return _http.store.request('GET', '/claims', pageSchema<Claim>(claimSchema),
        RequestOptions(query: {...?params?.toJson(), 'status': status is List ? status.join(',') : status}));
  }
`,
  },
  "StoreClient:claims.approve": {
    ts: "approve: ( claimId: string, deductAmount?: number, idempotencyKey?: string, options: { holdRefund?: boolean } = {}, ) => storeHttp.request(\"POST\", path`/claims/${claimId}/approve`, approveClaimResultSchema, { body: { ...(deductAmount !== undefined ? { deductAmount } : {}), ...(options.holdRefund ? { holdRefund: true } : {}), }, headers: idempotency(idempotencyKey), })",
    doc: "`POST /v1/claims/{claimId}/approve` — 클레임을 승인합니다. [options]의 `holdRefund`면 승인만 하고 결제 환불은 대기로 남깁니다.",
    dart: `
  Future<ApproveClaimResult> approve(String claimId,
          [int? deductAmount, String? idempotencyKey, ({bool? holdRefund})? options]) async =>
      _http.store.request('POST', '/claims/\${encodeURIComponent(claimId)}/approve', approveClaimResultSchema,
          RequestOptions(body: {
            if (deductAmount != null) 'deductAmount': deductAmount,
            if (options?.holdRefund ?? false) 'holdRefund': true,
          }, headers: _idempotency(idempotencyKey)));
`,
  },
  "StoreClient:claims.completeCollect": {
    ts: "completeCollect: (claimId: string, body?: ClaimCollectCompleteRequest) => storeHttp.requestVoid(\"POST\", path`/claims/${claimId}/collect/complete`, { ...(body ? { body: claimCollectCompleteRequestSchema.parse(body) } : {}), })",
    doc: "수거 완료 — `restock`으로 돌아온 조합·재입고 위치를 지정합니다. 생략하면 할당 순서·반품지 위치입니다.",
    dart: `
  Future<void> completeCollect(String claimId, [ClaimCollectCompleteRequest? body]) async => _http.store.requestVoid(
      'POST', '/claims/\${encodeURIComponent(claimId)}/collect/complete',
      RequestOptions(body: body == null ? absent : claimCollectCompleteRequestSchema.parse(body).toJson()));
`,
  },
  "StoreClient:claims.registerRedelivery": {
    ts: "registerRedelivery: ( claimId: string, carrierCode: string, trackingNumber: string, options: { inventoryLocationId?: string } = {}, ) => storeHttp.requestVoid(\"POST\", path`/claims/${claimId}/redelivery`, { body: { carrierCode, trackingNumber, ...(options.inventoryLocationId ? { inventoryLocationId: options.inventoryLocationId } : {}), }, })",
    doc: "교환 재배송 — [options]의 `inventoryLocationId`로 교환품을 보낼 위치를 지정합니다. 생략하면 그 상품의 기준 위치입니다.",
    dart: `
  Future<void> registerRedelivery(String claimId, String carrierCode, String trackingNumber,
          [({String? inventoryLocationId})? options]) async =>
      _http.store.requestVoid('POST', '/claims/\${encodeURIComponent(claimId)}/redelivery',
          RequestOptions(body: {
            'carrierCode': carrierCode,
            'trackingNumber': trackingNumber,
            if (truthy(options?.inventoryLocationId)) 'inventoryLocationId': options!.inventoryLocationId,
          }));
`,
  },
  "StoreClient:customers.listPointHistory": {
    ts: "listPointHistory: (customerId: string, params?: Omit<PointHistoryQuery, \"memberId\">) => storeHttp.request( \"GET\", path`/customers/${customerId}/points/history`, pageSchema(pointEntrySchema), { query: params as Query }, )",
    doc: "`GET /v1/customers/{customerId}/points/history` — 회원의 적립금 내역입니다. 회원은 경로로 정하므로 [params]에 `memberId`를 넣지 마십시오.",
    dart: `
  Future<Page<PointEntry>> listPointHistory(String customerId, [PointHistoryQuery? params]) async => _http.store.request(
      'GET', '/customers/\${encodeURIComponent(customerId)}/points/history', pageSchema<PointEntry>(pointEntrySchema),
      RequestOptions(query: params?.toJson()));
`,
  },
  "StoreClient:customers.list": {
    ts: "list: ( params?: PageParams & Omit<z.input<typeof customerListQuerySchema>, \"page\" | \"size\">, ) => storeHttp.request(\"GET\", \"/customers\", pageSchema(customerSummarySchema), { query: params as Query, })",
    doc: "`GET /v1/customers` — 회원 목록입니다.",
    dart: `
  Future<Page<CustomerSummary>> list(
          {int? page, int? size, String? q, String? joinedFrom, String? joinedTo, String? marketing, String? sort}) async =>
      _http.store.request('GET', '/customers', pageSchema<CustomerSummary>(customerSummarySchema),
          RequestOptions(query: {
            'page': page,
            'size': size,
            'q': q,
            'joinedFrom': joinedFrom,
            'joinedTo': joinedTo,
            'marketing': marketing,
            'sort': sort,
          }));
`,
  },
  "StoreClient:coupons.list": {
    ts: "list: (params?: PageParams & Omit<z.input<typeof couponListQuerySchema>, \"page\" | \"size\">) => storeHttp.request(\"GET\", \"/coupons\", pageSchema(couponSchema), { query: params as Query })",
    doc: "`GET /v1/coupons` — 쿠폰 목록입니다.",
    dart: `
  Future<Page<Coupon>> list(
          {int? page, int? size, String? status, String? kind, String? issueMethod, String? q}) async =>
      _http.store.request('GET', '/coupons', pageSchema<Coupon>(couponSchema),
          RequestOptions(query: {
            'page': page,
            'size': size,
            'status': status,
            'kind': kind,
            'issueMethod': issueMethod,
            'q': q,
          }));
`,
  },
  "StoreClient:paymentSettings.updateProvider": {
    ts: "updateProvider: updatePaymentProvider",
    doc: "`PATCH /v1/store/payment-providers/{provider}` — PG 사용 여부·샌드박스·간편결제를 바꿉니다.",
    dart: `
  Future<PaymentProvider> updateProvider(String provider, UpdatePaymentProviderRequest body) async => _http.store.request(
      'PATCH', '/store/payment-providers/\${encodeURIComponent(pgProviderSchema.parse(provider))}', paymentProviderSchema,
      RequestOptions(body: updatePaymentProviderRequestSchema.parse(body).toJson()));
`,
  },
  "StoreClient:paymentSettings.setSandboxMode": {
    ts: "setSandboxMode: (provider: PgProvider, sandboxMode: boolean) => updatePaymentProvider(provider, { sandboxMode })",
    doc: "PG의 샌드박스 모드를 바꿉니다. [updateProvider]에 `sandboxMode`만 보냅니다.",
    dart: `
  Future<PaymentProvider> setSandboxMode(String provider, bool sandboxMode) =>
      updateProvider(provider, UpdatePaymentProviderRequest(sandboxMode: sandboxMode));
`,
  },
  "StoreClient:paymentSettings.verify": {
    ts: "verify: (provider: PgProvider, body?: VerifyPaymentProviderRequest) => storeHttp.request( \"POST\", path`/store/payment-providers/${pgProviderSchema.parse(provider)}/verify`, paymentProviderVerificationSchema, { body: verifyPaymentProviderRequestSchema.parse(body ?? {}) }, )",
    doc: "`POST /v1/store/payment-providers/{provider}/verify` — 저장한 자격 증명으로 PG 연결을 확인합니다.",
    dart: `
  Future<PaymentProviderVerification> verify(String provider, [VerifyPaymentProviderRequest? body]) async => _http.store.request(
      'POST', '/store/payment-providers/\${encodeURIComponent(pgProviderSchema.parse(provider))}/verify',
      paymentProviderVerificationSchema,
      RequestOptions(body: verifyPaymentProviderRequestSchema.parse(body ?? const <String, Object?>{}).toJson()));
`,
  },
  "StoreClient:apps.installations.install": {
    ts: "install: ( input: string | { appId: string; settings?: AppInstallationSettingsUpdate[\"values\"] }, ) => storeHttp.request(\"POST\", \"/apps/installations\", appInstallationSchema, { body: appInstallRequestSchema.parse( typeof input === \"string\" ? { result: input } : input, ), })",
    doc: "`POST /v1/apps/installations` — 앱을 설치합니다.\n\n[input]은 동의 화면이 돌려준 결과 문자열이거나 `(appId: '…', settings: {…})` 레코드입니다.",
    dart: `
  Future<AppInstallation> install(Object input) async => _http.store.request('POST', '/apps/installations', appInstallationSchema,
      RequestOptions(
          body: appInstallRequestSchema
              .parse(switch (input) {
                String() => {'result': input},
                ({String appId, Map<String, Object?>? settings}) r => {
                    'appId': r.appId,
                    if (r.settings != null) 'settings': r.settings,
                  },
                _ => input,
              })
              .toJson()));
`,
  },
  "StoreClient:apiLogs.list": {
    ts: "list: (params?: ApiLogListOptions) => storeHttp.request(\"GET\", \"/api-logs\", apiLogPageSchema, { query: params && { ...params, principalType: Array.isArray(params.principalType) ? params.principalType.join(\",\") || undefined : params.principalType, }, })",
    doc: "API 요청 로그(최신순, 커서 페이지네이션)입니다. `principalType`에 목록을 주면 여러 주체를 한 번에 거릅니다.",
    dart: `
  Future<ApiLogPage> list([ApiLogListOptions? params]) async {
    final query = params?.toJson();
    final value = query?['principalType'];
    return _http.store.request('GET', '/api-logs', apiLogPageSchema,
        RequestOptions(
            query: query == null
                ? null
                : {...query, 'principalType': value is List ? (value.isEmpty ? null : value.join(',')) : value}));
  }
`,
  },
  "StoreClient:auditLogs.list": {
    ts: "list: (params?: AuditLogListOptions) => storeHttp.request(\"GET\", \"/audit-logs\", auditLogPageSchema, { query: params && { ...params, actorType: Array.isArray(params.actorType) ? params.actorType.join(\",\") || undefined : params.actorType, }, })",
    doc: "감사 로그(최신순, 커서 페이지네이션)입니다. 다음 페이지는 응답의 `nextCursor`를 `cursor`로 넘기십시오. `actorType`에 목록을 줄 수 있습니다.",
    dart: `
  Future<AuditLogPage> list([AuditLogListOptions? params]) async {
    final query = params?.toJson();
    final value = query?['actorType'];
    return _http.store.request('GET', '/audit-logs', auditLogPageSchema,
        RequestOptions(
            query: query == null
                ? null
                : {...query, 'actorType': value is List ? (value.isEmpty ? null : value.join(',')) : value}));
  }
`,
  },
  "StoreClient:approvalRequests.list": {
    ts: "list: (params?: ApprovalListOptions) => storeHttp.request(\"GET\", \"/approval-requests\", approvalPageSchema, { query: params && { ...params, status: Array.isArray(params.status) ? params.status.join(\",\") || undefined : params.status, }, })",
    doc: "승인 요청 목록(최신순, 커서 페이지네이션)입니다. `status`에 목록을 줄 수 있습니다.",
    dart: `
  Future<ApprovalPage> list([ApprovalListOptions? params]) async {
    final query = params?.toJson();
    final value = query?['status'];
    return _http.store.request('GET', '/approval-requests', approvalPageSchema,
        RequestOptions(
            query: query == null
                ? null
                : {...query, 'status': value is List ? (value.isEmpty ? null : value.join(',')) : value}));
  }
`,
  },
  "StoreClient:store.listInvitations": {
    ts: "listInvitations: (params?: { status?: Invitation[\"status\"] }) => storeHttp.request(\"GET\", \"/store/invitations\", z.array(invitationSchema), { query: params as Query, })",
    doc: "`GET /v1/store/invitations` — 구성원 초대 목록입니다. [status]로 거릅니다.",
    dart: `
  Future<List<Invitation>> listInvitations({String? status}) async =>
      _http.store.request('GET', '/store/invitations', z.array<Invitation>(invitationSchema), RequestOptions(query: {'status': status}));
`,
  },
};
