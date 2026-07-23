(() => {
  const ROUTE_EVENT = 'nq:native-route'
  const SHARE_EVENT = 'nq:native-share'
  const BRIDGE_AVAILABLE_EVENT = 'nq:native-bridge-available'
  const translations = {
    en: {
      hero: 'Freight decisions, ready for review.',
      ready: 'Local harness ready',
      offline: 'Offline — no action has been confirmed',
      routeEyebrow: 'Secure native route',
      dashboard: 'Decision inbox',
      quote: 'Quote intake',
      rates: 'Rate import',
      routeNote: 'No production credentials required. Native routes remain allowlisted.',
      shareEyebrow: 'Share Extension handoff',
      shareTitle: 'Shared content ready',
      shareFallback: 'Sanitized share payload received.',
      privacyNote: 'Review only. The harness never generates, sends, or finalizes a quote.',
      quickAction: 'Simulate Quick Action',
      showOffline: 'Show offline state',
      showOnline: 'Show reconnect state',
      footer: 'Local bridge harness',
    },
    vi: {
      hero: 'Quyết định vận tải, sẵn sàng để rà soát.',
      ready: 'Môi trường thử nghiệm đã sẵn sàng',
      offline: 'Ngoại tuyến — chưa có thao tác nào được xác nhận',
      routeEyebrow: 'Điều hướng native an toàn',
      dashboard: 'Việc cần xử lý',
      quote: 'Tiếp nhận báo giá',
      rates: 'Nhập bảng giá',
      routeNote: 'Không cần thông tin đăng nhập production. Điều hướng native luôn dùng allowlist.',
      shareEyebrow: 'Bàn giao từ Share Extension',
      shareTitle: 'Nội dung chia sẻ đã sẵn sàng',
      shareFallback: 'Đã nhận nội dung chia sẻ được làm sạch.',
      privacyNote: 'Chỉ để rà soát. Môi trường thử nghiệm không tạo, gửi hoặc chốt báo giá.',
      quickAction: 'Mô phỏng Quick Action',
      showOffline: 'Hiện trạng thái ngoại tuyến',
      showOnline: 'Hiện trạng thái kết nối lại',
      footer: 'Môi trường thử bridge cục bộ',
    },
  }
  const locale = navigator.language.toLowerCase().startsWith('vi') ? 'vi' : 'en'
  const copy = translations[locale]
  let pendingShare = null
  let offlineDemo = false

  const bridge = () => window.webkit?.messageHandlers?.nqBridge
  const post = (message) => bridge()?.postMessage(message)
  const announceReady = () => post({ type: 'ready', version: 1 })

  const routeTitle = (path) => {
    if (path.startsWith('/app/quotes/new')) return copy.quote
    if (path.startsWith('/app/rates/import')) return copy.rates
    return copy.dashboard
  }

  const renderConnection = () => {
    const offline = offlineDemo || navigator.onLine === false
    document.body.classList.toggle('offline', offline)
    document.querySelector('#connection-label').textContent = offline ? copy.offline : copy.ready
    document.querySelector('#offline-action').textContent = offline ? copy.showOnline : copy.showOffline
  }

  const localize = () => {
    document.documentElement.lang = locale
    document.querySelectorAll('[data-i18n]').forEach((element) => {
      const value = copy[element.dataset.i18n]
      if (value) element.textContent = value
    })
    document.querySelector('#route-title').textContent = copy.dashboard
  }

  window.addEventListener(SHARE_EVENT, (event) => {
    const payload = event.detail?.payload
    if (!payload || typeof payload !== 'object') return
    pendingShare = payload
  })

  window.addEventListener(BRIDGE_AVAILABLE_EVENT, announceReady)

  window.addEventListener(ROUTE_EVENT, (event) => {
    const { id, path } = event.detail || {}
    if (typeof id !== 'string' || typeof path !== 'string') return
    document.querySelector('#route-title').textContent = routeTitle(path)
    document.querySelector('#route-path').textContent = path

    if (pendingShare) {
      const shareCard = document.querySelector('#share-card')
      const preview = pendingShare.text || pendingShare.title || pendingShare.url || copy.shareFallback
      document.querySelector('#share-text').textContent = preview
      shareCard.hidden = false
      pendingShare = null
    }

    post({ type: 'ack', id, status: 'accepted' })
  })

  window.addEventListener('online', renderConnection)
  window.addEventListener('offline', renderConnection)

  document.addEventListener('DOMContentLoaded', () => {
    localize()
    renderConnection()
    document.querySelector('#quick-action').addEventListener('click', () => {
      post({
        type: 'harness-route',
        path: '/app/quotes/new?intent=quick-create&focus=intake&source=shortcut',
      })
    })
    document.querySelector('#offline-action').addEventListener('click', () => {
      offlineDemo = !offlineDemo
      renderConnection()
    })
    announceReady()
  })
})()
