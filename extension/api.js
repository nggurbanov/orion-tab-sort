/* global browser, chrome */
(() => {
  const promiseAPI = typeof browser !== "undefined";
  const api = promiseAPI ? browser : typeof chrome !== "undefined" ? chrome : {};
  globalThis.probeAPI = {
    raw: api,
    call(scope, method, ...args) {
      const target = scope.split(".").reduce((value, key) => value?.[key], api);
      if (typeof target?.[method] !== "function") {
        return Promise.reject(new Error(`Unavailable API: ${scope}.${method}`));
      }
      if (promiseAPI) return Promise.resolve(target[method](...args));
      return new Promise((resolve, reject) => {
        target[method](...args, result => {
          const error = api.runtime.lastError;
          if (error) reject(new Error(error.message));
          else resolve(result);
        });
      });
    }
  };
})();
