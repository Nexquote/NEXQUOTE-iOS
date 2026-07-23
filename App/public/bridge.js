(() => {
  const ROUTE_EVENT = 'nq:native-route'
  const SHARE_EVENT = 'nq:native-share'
  const BRIDGE_AVAILABLE_EVENT = 'nq:native-bridge-available'
  let pendingShare = null
  let offlineDemo = false

  const bridge = () => window.webkit?.messageHandlers?.nqBridge
  const post = (message) => bridge()?.postMessage(message)
  const announceReady = () => post({ type: 'ready', version: 1 })

  const routeTitle = (path) => {
    if (path.startsWith('/app/quotes/new')) return 'Quote intake'
    if (path.startsWith('/app/rates/import')) return 'Rate import'
    return 'Decision inbox'
  }

  const renderConnection = () => {
    const offline = offlineDemo || navigator.onLine === false
    document.body.classList.toggle('offline', offline)
    document.querySelector('#connection-label').textContent = offline
      ? 'Offline — no action has been confirmed'
      : 'Local harness ready'
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
      const preview = pendingShare.text || pendingShare.title || pendingShare.url || 'Sanitized share payload received.'
      document.querySelector('#share-text').textContent = preview
      shareCard.hidden = false
      pendingShare = null
    }

    post({ type: 'ack', id, status: 'accepted' })
  })

  window.addEventListener('online', renderConnection)
  window.addEventListener('offline', renderConnection)

  document.addEventListener('DOMContentLoaded', () => {
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
