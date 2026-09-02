## ✅ When to Trigger Client Logs

| Scenario                        | Should You Log? | Why                                                                     |
| ------------------------------- | --------------- | ----------------------------------------------------------------------- |
| **API call fails (400/500)**    | ❌ **NO**       | Backend already logs errors. Frontend just shows user-friendly message. |
| **Page fails to render**        | ✅ **YES**      | React error boundary catches this. Component tree crashed.              |
| **JavaScript runtime error**    | ✅ **YES**      | Uncaught exceptions, `undefined` errors.                                |
| **Storage mismatch/empty**      | ✅ **YES**      | Cache issues, localStorage missing expected keys.                       |
| **User action triggers error**  | ✅ **YES**      | Click handler fails, form submission fails.                             |
| **Network request fails**       | ❌ **NO**       | Backend logs it. Frontend shouldn't duplicate.                          |
| **3rd party script fails**      | ✅ **YES**      | External service (Google Maps, Stripe) fails.                           |
| **API returns unexpected data** | ✅ **YES**      | Response structure changed, parsing fails.                              |

---

## 📊 The Golden Rule

```
Log FRONTEND errors → when the UI itself fails
Don't log BACKEND errors → the API already logs them
```

---

## 🔍 Common Frontend Errors You Should Log

1. **React/Vue Component Errors**
   - Error boundaries catching render failures
   - Component lifecycle errors

2. **Storage/Cache Issues**
   - `localStorage.getItem('user')` returns `null` when expected
   - Parsing JSON from storage fails

3. **Route/URL Issues**
   - Invalid route params
   - Missing query parameters

4. **Third-party Integration Failures**
   - Stripe.js fails to load
   - Google Maps API error
   - Firebase/FCM initialization fails

5. **Data Parsing Errors**
   - API returns unexpected data shape
   - Missing required fields in response

6. **Unhandled Promise Rejections**
   - Async/await errors not caught

---

## ✅ Frontend Logger Implementation (You'll Build Later)

```typescript
// src/services/ErrorLogger.ts

class ErrorLogger {
  // ❌ DON'T do this - API errors already logged by backend
  logApiError(apiError: any) {
    // Never call this for API errors
  }

  // ✅ DO this - UI/rendering errors
  logUIError(error: Error, component: string) {
    this.sendToBackend(error, { component, type: "ui_error" });
  }

  // ✅ DO this - Storage issues
  logStorageIssue(key: string, expected: any, actual: any) {
    this.sendToBackend(new Error(`Storage mismatch for key: ${key}`), {
      key,
      expected,
      actual,
      type: "storage_issue",
    });
  }

  // ✅ DO this - Third-party failures
  logThirdPartyError(service: string, error: Error) {
    this.sendToBackend(error, { service, type: "third_party" });
  }

  // ✅ DO this - Unhandled rejections
  logUnhandledRejection(reason: any) {
    this.sendToBackend(new Error("Unhandled Promise Rejection"), {
      reason,
      type: "unhandled_rejection",
    });
  }
}
```

---

## 📝 Summary

| What Happened                | Log to Backend?      |
| ---------------------------- | -------------------- |
| API returns 500              | ❌ No (backend logs) |
| API returns 401              | ❌ No (backend logs) |
| **React component crashes**  | ✅ **Yes**           |
| **localStorage missing key** | ✅ **Yes**           |
| **JSON parsing fails**       | ✅ **Yes**           |
| **Stripe.js fails to load**  | ✅ **Yes**           |
| **Route params invalid**     | ✅ **Yes**           |
| Network timeout              | ❌ No (backend logs) |

**Bottom line:** Only log errors that happen **in the browser**, not errors that come from the server. 🚀
