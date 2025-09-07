var Combo = Combo || {};
Combo.HTML = (() => {
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // src/html/index.js
  var html_exports = {};
  __export(html_exports, {
    default: () => html_default,
    init: () => init
  });
  function init() {
    var PolyfillEvent = eventConstructor();
    function eventConstructor() {
      if (typeof window.CustomEvent === "function") return window.CustomEvent;
      function CustomEvent(event, params) {
        params = params || { bubbles: false, cancelable: false, detail: void 0 };
        var evt = document.createEvent("CustomEvent");
        evt.initCustomEvent(event, params.bubbles, params.cancelable, params.detail);
        return evt;
      }
      CustomEvent.prototype = window.Event.prototype;
      return CustomEvent;
    }
    function buildHiddenInput(name, value) {
      var input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      input.value = value;
      return input;
    }
    function handleClick(element, targetModifierKey) {
      var to = element.getAttribute("data-to"), method = buildHiddenInput("_method", element.getAttribute("data-method")), csrf = buildHiddenInput("_csrf_token", element.getAttribute("data-csrf")), form = document.createElement("form"), submit = document.createElement("input"), target = element.getAttribute("target");
      form.method = element.getAttribute("data-method") === "get" ? "get" : "post";
      form.action = to;
      form.style.display = "none";
      if (target) form.target = target;
      else if (targetModifierKey) form.target = "_blank";
      form.appendChild(csrf);
      form.appendChild(method);
      document.body.appendChild(form);
      submit.type = "submit";
      form.appendChild(submit);
      submit.click();
    }
    window.addEventListener(
      "click",
      function(e) {
        var element = e.target;
        if (e.defaultPrevented) return;
        while (element && element.getAttribute) {
          var comboLinkEvent = new PolyfillEvent("combo.link.click", {
            bubbles: true,
            cancelable: true
          });
          if (!element.dispatchEvent(comboLinkEvent)) {
            e.preventDefault();
            e.stopImmediatePropagation();
            return false;
          }
          if (element.getAttribute("data-method") && element.getAttribute("data-to")) {
            handleClick(element, e.metaKey || e.shiftKey);
            e.preventDefault();
            return false;
          } else {
            element = element.parentNode;
          }
        }
      },
      false
    );
    window.addEventListener(
      "combo.link.click",
      function(e) {
        var message = e.target.getAttribute("data-confirm");
        if (message && !window.confirm(message)) {
          e.preventDefault();
        }
      },
      false
    );
  }
  var html_default = { init };
  return __toCommonJS(html_exports);
})();
//# sourceMappingURL=html.js.map
