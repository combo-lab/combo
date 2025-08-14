import { Socket } from '../socket'

function init(url, interval, targetWindow, reloadPageOnCssChanges) {
  const socket = new Socket(url)

  let getFreshUrl = (url) => {
    let date = Math.round(Date.now() / 1000).toString()
    let cleanUrl = url.replace(/(&|\?)vsn=\d*/, '')
    let freshUrl = cleanUrl + (cleanUrl.includes('?') ? '&' : '?') + 'vsn=' + date
    return freshUrl
  }

  let buildFreshLinkUrl = (link) => {
    let newLink = document.createElement('link')
    let onComplete = () => {
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

  let buildFreshImportUrl = (style) => {
    let newStyle = document.createElement('style')
    let onComplete = () => {
      if (style.parentNode !== null) {
        style.parentNode.removeChild(style)
      }
    }

    let originalCSS = style.textContent || style.innerHTML
    let freshCSS = originalCSS.replace(/@import\s+(?:url\()?['"]?([^'"\)]+)['"]?\)?/g, (match, url) => {
      const freshUrl = getFreshUrl(url)

      if (match.includes('url(')) {
        return `@import url("${freshUrl}")`
      }
      else {
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

  let repaint = () => {
    const browser = navigator.userAgent.toLowerCase()
    if (browser.includes('chrome')) {
      setTimeout(() => document.body.offsetHeight, 25)
    }
  }

  let pageStrategy = (channel) => {
    channel.off('assets_change')
    window[targetWindow].location.reload()
  }

  let cssStrategy = () => {
    let reloadableLinkElements = window.parent.document.querySelectorAll(
      'link[rel=stylesheet]:not([data-no-reload]):not([data-pending-removal])',
    )

    Array.from(reloadableLinkElements)
      .filter(link => link.href)
      .forEach(link => buildFreshLinkUrl(link))

    let reloadablestyles = window.parent.document.querySelectorAll(
      'style:not([data-no-reload]):not([data-pending-removal])',
    )

    Array.from(reloadablestyles)
      .filter(style => style.textContent.includes('@import'))
      .forEach(style => buildFreshImportUrl(style))

    repaint()
  }

  let reloadStrategies = {
    css: reloadPageOnCssChanges ? pageStrategy : cssStrategy,
    page: pageStrategy,
  }

  class LiveReloader {
    constructor(socket) {
      this.socket = socket
      this.enabledOnce = false
    }

    enable() {
      this.socket.onOpen(() => {
        if (this.enabledOnce) {
          return
        }
        else {
          this.enabledOnce = true
        }

        if (['complete', 'loaded', 'interactive'].includes(parent.document.readyState)) {
          this.dispatchConnected()
        }
        else {
          parent.addEventListener('load', () => this.dispatchConnected())
        }
      })

      this.channel = socket.channel('combo:live_reload', {})
      this.channel.on('assets_change', (msg) => {
        let reloadStrategy = reloadStrategies[msg.asset_type] || reloadStrategies.page
        setTimeout(() => reloadStrategy(this.channel), interval)
      })
      this.channel.join()
      this.socket.connect()
    }

    disable() {
      this.channel.leave()
      socket.disconnect()
    }

    dispatchConnected() {
      parent.dispatchEvent(new CustomEvent('combo:live_reload:attached', { detail: this }))
    }
  }

  const reloader = new LiveReloader(socket)
  reloader.enable()
}

export { init }
export default { init }
