import { Socket } from 'combo/socket'
import debounce from 'lodash.debounce'

function getFreshUrl(url) {
  const date = Math.round(Date.now() / 1000).toString()
  const cleanUrl = url.replace(/(&|\?)vsn=\d*/, '')
  const freshUrl = cleanUrl + (cleanUrl.includes('?') ? '&' : '?') + 'vsn=' + date
  return freshUrl
}

function buildFreshImportUrl(style) {
  const newStyle = document.createElement('style')
  const onComplete = () => {
    if (style.parentNode !== null) {
      style.parentNode.removeChild(style)
    }
  }

  const originalCSS = style.textContent || style.innerHTML
  const freshCSS = originalCSS.replace(/@import\s+(?:url\()?['"]?([^'"\)]+)['"]?\)?/g, (match, url) => {
    const freshUrl = getFreshUrl(url)

    if (match.includes('url(')) {
      return `@import url("${freshUrl}")`
    } else {
      return `@import "${freshUrl}"`
    }
  })

  newStyle.onerror = onComplete
  newStyle.onload = onComplete
  style.setAttribute('data-pending-removal', '')
  newStyle.setAttribute('type', 'text/css')
  newStyle.textContent = freshCSS

  style.parentNode.insertBefore(newStyle, style.nextSibling)
  return newStyle
}

function buildFreshLinkUrl(link) {
  const newLink = document.createElement('link')
  const onComplete = () => {
    if (link.parentNode !== null) {
      link.parentNode.removeChild(link)
    }
  }

  newLink.onerror = onComplete
  newLink.onload = onComplete
  link.setAttribute('data-pending-removal', '')
  newLink.setAttribute('rel', 'stylesheet')
  newLink.setAttribute('type', 'text/css')
  newLink.setAttribute('href', getFreshUrl(link.href))
  link.parentNode.insertBefore(newLink, link.nextSibling)
  return newLink
}

function repaint() {
  const browser = navigator.userAgent.toLowerCase()
  if (browser.includes('chrome')) {
    setTimeout(() => document.body.offsetHeight, 25)
  }
}

function buildReloadStrategies(targetWindow, fullReloadOnCssChanges) {
  const fullReloadTargetWindow = {
    type: 'full_reload',
    priority: 9,
    fun: () => {
      window[targetWindow].location.reload()
    },
  }

  const hotReloadCSS = {
    type: 'hot_reload',
    priority: 1,
    fun: () => {
      const reloadableLinkElements = window.parent.document.querySelectorAll(
        'link[rel=stylesheet]:not([data-no-reload]):not([data-pending-removal])',
      )

      Array.from(reloadableLinkElements)
        .filter(link => link.href)
        .forEach(link => buildFreshLinkUrl(link))

      const reloadablestyles = window.parent.document.querySelectorAll(
        'style:not([data-no-reload]):not([data-pending-removal])',
      )

      Array.from(reloadablestyles)
        .filter(style => style.textContent.includes('@import'))
        .forEach(style => buildFreshImportUrl(style))

      repaint()
    },
  }

  return {
    css: fullReloadOnCssChanges ? fullReloadTargetWindow : hotReloadCSS,
    __default__: fullReloadTargetWindow,
  }
}

class LiveReloader {
  constructor(path, debounceTime, targetWindow, fullReloadOnCssChanges) {
    this.enabledOnce = false
    this.reloadQueue = []

    this.socket = new Socket(path)
    this.debouncedReload = debounce(this.reload, debounceTime)
    this.reloadStrategies = buildReloadStrategies(targetWindow, fullReloadOnCssChanges)

    this.channel = this.socket.channel('combo:live_reloader', {})
    this.socket.onOpen(() => {
      if (this.enabledOnce) {
        return
      } else {
        this.enabledOnce = true
      }

      if (['complete', 'loaded', 'interactive'].includes(parent.document.readyState)) {
        this.dispatchConnected()
      } else {
        parent.addEventListener('load', () => this.dispatchConnected())
      }
    })
    this.channel.on('reload', (msg) => {
      const { type: type } = msg
      this.scheduleReload(type)
    })
  }

  enable() {
    this.channel.join()
    this.socket.connect()
  }

  disable() {
    this.channel.leave()
    this.socket.disconnect()

    this.enabledOnce = false
    this.reloadQueue = []
  }

  dispatchConnected() {
    parent.dispatchEvent(new CustomEvent('combo:live_reloader:connected', { detail: this }))
  }

  scheduleReload(type) {
    this.reloadQueue.push(type)
    this.debouncedReload()
  }

  reload() {
    const reloadStrategies = this.reloadQueue.map(type => this.getReloadStrategy(type))
    const finalReloadStrategy = reloadStrategies.reduce((acc, current) => {
      return current.priority > acc.priority ? current : acc
    })

    const { type: reload_type, fun: reload_fun } = finalReloadStrategy
    if (reload_type == 'full_reload') {
      this.channel.off('reload')
    }
    reload_fun()

    this.reloadQueue = []
  }

  getReloadStrategy(type) {
    return this.reloadStrategies[type] || this.reloadStrategies.__default__
  }
}

export default LiveReloader
