(function() {
    'use strict';

    // === INTERCEPT BROWSER NOTIFICATIONS ===
    if (!window.__messengerNotificationBridgeInstalled) {
        Object.defineProperty(window, 'Notification', {
            value: class FakeNotification {
                static get permission() { return 'granted'; }
                static requestPermission(cb) {
                    if (cb) cb('granted');
                    return Promise.resolve('granted');
                }

                constructor(title, options = {}) {
                    window.webkit.messageHandlers.notificationBridge.postMessage({
                        title: title,
                        body: options.body || '',
                        icon: options.icon || '',
                        tag: options.tag || '',
                        data: options.data || {}
                    });

                    this._onclick = null;
                    this._onclose = null;
                }

                set onclick(fn) { this._onclick = fn; }
                get onclick() { return this._onclick; }
                set onclose(fn) { this._onclose = fn; }
                get onclose() { return this._onclose; }
                close() {}
            },
            writable: false,
            configurable: false
        });
    }

    // === UNREAD COUNT OBSERVER ===
    // Clean up previous instance if re-injected
    if (window.__messengerUnreadInterval) {
        clearInterval(window.__messengerUnreadInterval);
    }
    if (window.__messengerTitleObserver) {
        window.__messengerTitleObserver.disconnect();
    }

    let lastCount = -1;
    let debounceTimer = null;

    function sendUnreadCount() {
        const title = document.title;
        const match = title.match(/\((\d+)\)/);
        const count = match ? parseInt(match[1], 10) : 0;
        if (count !== lastCount) {
            lastCount = count;
            window.webkit.messageHandlers.unreadCount.postMessage(count);
        }
    }

    function debouncedSendUnreadCount() {
        if (debounceTimer) clearTimeout(debounceTimer);
        debounceTimer = setTimeout(sendUnreadCount, 500);
    }

    const titleObserver = new MutationObserver(debouncedSendUnreadCount);
    window.__messengerTitleObserver = titleObserver;

    const titleElement = document.querySelector('title');
    if (titleElement) {
        titleObserver.observe(titleElement, { childList: true });
    }

    window.__messengerUnreadInterval = setInterval(sendUnreadCount, 5000);
    window.__messengerNotificationBridgeInstalled = true;
})();
