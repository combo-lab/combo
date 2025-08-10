/**
 * Combo HTML
 *
 * It provides enhancements for HTML:
 *
 * - Support `data-confirm="message"` attributes, which shows
 *   a confirmation modal with the given message.
 *
 * - Support `data-method="patch|post|put|delete"` attributes,
 *   which sends the current click as a PATCH/POST/PUT/DELETE
 *   HTTP request. You will need to add `data-to` with the URL
 *   and `data-csrf` with the CSRF token value.
 *
 * - Dispatch a `combo.link.click` event, which provides a mechanism to
 *   customize the default behaviour above.
 *   Stopping propagation for this event will disable `data-confirm`.
 *   Prevent default behaviour for this event will disable `data-method`.
 *
 * ## Setup
 *
 * To use the functionality above, you must load code into your build tool:
 *
 * ```javascript
 * import html from "combo/html";
 *
 * html.init();
 * ```
 *
 * ## Customizing the default behaivour
 *
 * ### Customizing the `data-confirm` behaviour
 *
 * Intercept the `combo.link.click` event before it bubbling up to `window`
 * and do your own custom logic.
 *
 * For example, you could replace the default behavior using `window.confirm`
 * with a custom implementation based on [vex](https://github.com/HubSpot/vex):
 *
 * ```javascript
 * // Compared to window.confirm, the custom dialog does not block JavaScript
 * // execution. Therefore to make this work as expected we store the successful
 * // confirmation as an attribute and re-trigger the click event.
 *
 * // On the second click, the `data-confirm-resolved` attribute is set
 * // and we proceed.
 * const RESOLVED_ATTRIBUTE = "data-confirm-resolved";
 *
 * // listen on document.body, so it's executed before the default of
 * // html.init(), which is listening on the window object.
 * document.body.addEventListener(
 *   "combo.link.click",
 *   function (e) {
 *     // Prevent default implementation
 *     e.stopPropagation();
 *
 *     // Introduce alternative implementation
 *     const message = e.target.getAttribute("data-confirm");
 *     if (!message) {
 *       return;
 *     }
 *
 *     // Confirm is resolved execute the click event
 *     if (e.target?.hasAttribute(RESOLVED_ATTRIBUTE)) {
 *       e.target.removeAttribute(RESOLVED_ATTRIBUTE);
 *       return;
 *     }
 *
 *     // Confirm is needed, preventDefault and show your modal
 *     e.preventDefault();
 *     e.target?.setAttribute(RESOLVED_ATTRIBUTE, "");
 *
 *     vex.dialog.confirm({
 *       message: message,
 *       callback: function (value) {
 *         if (value == true) {
 *           // Customer confirmed, re-trigger the click event.
 *           e.target?.click();
 *         } else {
 *           // Customer canceled
 *           e.target?.removeAttribute(RESOLVED_ATTRIBUTE);
 *         }
 *       },
 *     });
 *   },
 *   false,
 * );
 * ```
 *
 * ### Creating new custom behavior
 *
 * ```javascript
 * window.addEventListener(
 *   "combo.link.click",
 *   function (e) {
 *     // Introduce new behaviour
 *     var message = e.target.getAttribute("data-prompt");
 *     var answer = e.target.getAttribute("data-prompt-answer");
 *     if (message && answer && answer != window.prompt(message)) {
 *       e.preventDefault();
 *     }
 *   },
 *   false,
 * );
 * ```
 */

function init() {
  var PolyfillEvent = eventConstructor()

  function eventConstructor() {
    if (typeof window.CustomEvent === 'function') return window.CustomEvent
    // IE<=9 Support
    function CustomEvent(event, params) {
      params = params || { bubbles: false, cancelable: false, detail: undefined }
      var evt = document.createEvent('CustomEvent')
      evt.initCustomEvent(event, params.bubbles, params.cancelable, params.detail)
      return evt
    }
    CustomEvent.prototype = window.Event.prototype
    return CustomEvent
  }

  function buildHiddenInput(name, value) {
    var input = document.createElement('input')
    input.type = 'hidden'
    input.name = name
    input.value = value
    return input
  }

  function handleClick(element, targetModifierKey) {
    var to = element.getAttribute('data-to'),
      method = buildHiddenInput('_method', element.getAttribute('data-method')),
      csrf = buildHiddenInput('_csrf_token', element.getAttribute('data-csrf')),
      form = document.createElement('form'),
      submit = document.createElement('input'),
      target = element.getAttribute('target')

    form.method = element.getAttribute('data-method') === 'get' ? 'get' : 'post'
    form.action = to
    form.style.display = 'none'

    if (target) form.target = target
    else if (targetModifierKey) form.target = '_blank'

    form.appendChild(csrf)
    form.appendChild(method)
    document.body.appendChild(form)

    // Insert a button and click it instead of using `form.submit`
    // because the `submit` function does not emit a `submit` event.
    submit.type = 'submit'
    form.appendChild(submit)
    submit.click()
  }

  window.addEventListener(
    'click',
    function (e) {
      var element = e.target
      if (e.defaultPrevented) return

      while (element && element.getAttribute) {
        var comboLinkEvent = new PolyfillEvent('combo.link.click', {
          bubbles: true,
          cancelable: true,
        })

        if (!element.dispatchEvent(comboLinkEvent)) {
          e.preventDefault()
          e.stopImmediatePropagation()
          return false
        }

        if (element.getAttribute('data-method') && element.getAttribute('data-to')) {
          handleClick(element, e.metaKey || e.shiftKey)
          e.preventDefault()
          return false
        } else {
          element = element.parentNode
        }
      }
    },
    false,
  )

  window.addEventListener(
    'combo.link.click',
    function (e) {
      var message = e.target.getAttribute('data-confirm')
      if (message && !window.confirm(message)) {
        e.preventDefault()
      }
    },
    false,
  )
}

export { init }
export default { init }
