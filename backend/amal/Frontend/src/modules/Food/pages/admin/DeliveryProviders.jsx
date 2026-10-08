import { useCallback, useEffect, useMemo, useState } from "react"
import {
  AlertTriangle, CheckCircle2, ExternalLink, Loader2, Pencil, PlayCircle,
  RefreshCw, Search, Truck, X, XCircle,
} from "lucide-react"
import { toast } from "sonner"
import { adminAPI } from "@food/api"

/**
 * Third-party delivery (Delhivery Local), configured per zone.
 *
 * A zone with no settings — or switched off — keeps using our own riders, so
 * this page can never break a zone by being left alone.
 */

const MODES = [
  { value: "own", label: "Own riders only", hint: "Delhivery is never used." },
  { value: "delhivery", label: "Delhivery only", hint: "Every prepaid order goes to Delhivery." },
  { value: "delhivery_then_own", label: "Delhivery, then own riders", hint: "Delhivery first; own riders if it finds nobody." },
  { value: "own_then_delhivery", label: "Own riders, then Delhivery", hint: "Own riders first; Delhivery after the timeout." },
]
const NO_RIDER = [
  { value: "notify_admin", label: "Retry once, then alert admin" },
  { value: "fallback_own", label: "Hand to own riders" },
  { value: "cancel_refund", label: "Cancel and refund the customer" },
]
const CONFIRM = [
  { value: "prep_aligned", label: "Time it to the food being ready" },
  { value: "on_accept", label: "As soon as the restaurant accepts" },
  { value: "on_ready", label: "Only when marked ready for pickup" },
]
const CANCEL_REASONS = [
  "service is no longer required",
  "taking too long to assign a driver",
  "requested wrong vehicle",
  "requested wrong pickup or destination",
  "pickup tat breached",
  "fraudulent rider behaviour",
]

const label = (list, value) => list.find((x) => x.value === value)?.label || value
const rupees = (n) => (n === null || n === undefined ? "—" : `₹${Number(n).toFixed(0)}`)
const when = (d) => (d ? new Date(d).toLocaleString() : "—")
const errMsg = (err, fallback) => err?.response?.data?.message || err?.message || fallback

const FULFILMENT_STYLE = {
  pending: "bg-slate-100 text-slate-700",
  searching_for_agent: "bg-amber-100 text-amber-800",
  agent_assigned: "bg-blue-100 text-blue-800",
  at_pickup: "bg-blue-100 text-blue-800",
  out_for_delivery: "bg-indigo-100 text-indigo-800",
  at_delivery: "bg-indigo-100 text-indigo-800",
  order_delivered: "bg-emerald-100 text-emerald-800",
  cancelled: "bg-rose-100 text-rose-800",
}

function Badge({ className = "", children }) {
  return <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${className}`}>{children}</span>
}

function Field({ label: text, hint, children }) {
  return (
    <label className="block">
      <span className="block text-xs font-semibold text-slate-700 mb-1">{text}</span>
      {children}
      {hint && <span className="block mt-1 text-[11px] text-slate-500">{hint}</span>}
    </label>
  )
}

const inputCls = "w-full px-3 py-2 text-sm rounded-lg border border-slate-300 bg-white focus:outline-none focus:ring-2 focus:ring-blue-500"

function ZoneConfigModal({ zone, vehicleModes, onClose, onSaved }) {
  const [form, setForm] = useState(() => ({
    mode: zone.mode,
    isEnabled: zone.isEnabled,
    vehicleMode: zone.vehicleMode,
    assignTimeoutMin: zone.assignTimeoutMin,
    onNoRider: zone.onNoRider,
    confirmPolicy: zone.confirmPolicy,
    defaultPrepMinutes: zone.defaultPrepMinutes,
    maxFare: zone.maxFare ?? "",
    checkServiceability: zone.checkServiceability,
    pickupOtpEnabled: false,
  }))
  const [saving, setSaving] = useState(false)
  const set = (k, v) => setForm((p) => ({ ...p, [k]: v }))
  const usesDelhivery = form.mode !== "own"

  const save = async () => {
    try {
      setSaving(true)
      await adminAPI.saveZoneDeliveryConfig(zone.zoneId, {
        ...form,
        assignTimeoutMin: Number(form.assignTimeoutMin),
        defaultPrepMinutes: Number(form.defaultPrepMinutes),
        maxFare: form.maxFare === "" ? null : Number(form.maxFare),
      })
      toast.success(`Saved delivery settings for ${zone.zoneName}`)
      onSaved()
    } catch (err) {
      toast.error(errMsg(err, "Could not save"))
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-200">
          <div>
            <h3 className="text-lg font-bold text-slate-900">Delivery for {zone.zoneName}</h3>
            <p className="text-xs text-slate-500">Changes apply to orders the restaurant accepts from now on.</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-slate-100"><X className="w-5 h-5" /></button>
        </div>

        <div className="p-6 space-y-5">
          <div className="flex items-center justify-between rounded-xl border border-slate-200 p-4">
            <div>
              <p className="text-sm font-semibold text-slate-900">Enabled</p>
              <p className="text-xs text-slate-500">Off = this zone uses own riders, whatever the mode says.</p>
            </div>
            <button
              type="button"
              onClick={() => set("isEnabled", !form.isEnabled)}
              className={`relative w-12 h-7 rounded-full transition-colors ${form.isEnabled ? "bg-emerald-500" : "bg-slate-300"}`}
              aria-pressed={form.isEnabled}
            >
              <span className={`absolute top-1 w-5 h-5 rounded-full bg-white shadow transition-all ${form.isEnabled ? "left-6" : "left-1"}`} />
            </button>
          </div>

          <Field label="Who delivers" hint={MODES.find((m) => m.value === form.mode)?.hint}>
            <select className={inputCls} value={form.mode} onChange={(e) => set("mode", e.target.value)}>
              {MODES.map((m) => <option key={m.value} value={m.value}>{m.label}</option>)}
            </select>
          </Field>

          {usesDelhivery && (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Field label="Vehicle" hint="Food: 2-wheeler.">
                <select className={inputCls} value={form.vehicleMode} onChange={(e) => set("vehicleMode", e.target.value)}>
                  {vehicleModes.map((v) => <option key={v} value={v}>{v}</option>)}
                </select>
              </Field>
              <Field label="Minutes to find a rider" hint={form.mode === "own_then_delhivery" ? "Own riders get this long before Delhivery." : "Then the no-rider rule applies."}>
                <input type="number" min={2} max={60} className={inputCls} value={form.assignTimeoutMin} onChange={(e) => set("assignTimeoutMin", e.target.value)} />
              </Field>
              <Field label="If no rider is found">
                <select className={inputCls} value={form.onNoRider} onChange={(e) => set("onNoRider", e.target.value)}>
                  {NO_RIDER.map((m) => <option key={m.value} value={m.value}>{m.label}</option>)}
                </select>
              </Field>
              <Field label="When to send the rider" hint="Delhivery reaches the restaurant in about 15 minutes.">
                <select className={inputCls} value={form.confirmPolicy} onChange={(e) => set("confirmPolicy", e.target.value)}>
                  {CONFIRM.map((m) => <option key={m.value} value={m.value}>{m.label}</option>)}
                </select>
              </Field>
              {form.confirmPolicy === "prep_aligned" && (
                <Field label="Typical prep time (minutes)" hint="The rider is released so they arrive as the food is ready.">
                  <input type="number" min={0} max={120} className={inputCls} value={form.defaultPrepMinutes} onChange={(e) => set("defaultPrepMinutes", e.target.value)} />
                </Field>
              )}
              <Field label="Maximum Delhivery fare (₹)" hint="Above this the order is treated as no rider. Blank = no cap.">
                <input type="number" min={1} className={inputCls} value={form.maxFare} onChange={(e) => set("maxFare", e.target.value)} placeholder="e.g. 120" />
              </Field>
              <label className="flex items-start gap-3 sm:col-span-2 rounded-xl border border-slate-200 p-3">
                <input type="checkbox" className="mt-1" checked={form.checkServiceability} onChange={(e) => set("checkServiceability", e.target.checked)} />
                <span>
                  <span className="block text-sm font-semibold text-slate-900">Check the address at checkout</span>
                  <span className="block text-xs text-slate-500">Customers at an address Delhivery cannot serve are told before they pay.</span>
                </span>
              </label>
            </div>
          )}

          {form.mode === "delhivery" && form.onNoRider !== "fallback_own" && (
            <p className="text-xs text-amber-800 bg-amber-50 border border-amber-200 rounded-lg p-3">
              Cash and pay-on-delivery orders are refused in this zone — a Delhivery rider can't collect money.
            </p>
          )}
        </div>

        <div className="flex justify-end gap-2 px-6 py-4 border-t border-slate-200">
          <button onClick={onClose} className="px-4 py-2 rounded-lg border border-slate-300 text-sm font-semibold text-slate-700 hover:bg-slate-50">Cancel</button>
          <button onClick={save} disabled={saving} className="px-4 py-2 rounded-lg bg-slate-900 text-white text-sm font-semibold hover:bg-slate-800 disabled:opacity-60 inline-flex items-center gap-2">
            {saving && <Loader2 className="w-4 h-4 animate-spin" />} Save
          </button>
        </div>
      </div>
    </div>
  )
}

function QuoteResult({ result, onClose }) {
  if (!result) return null
  return (
    <div className="mt-3 rounded-xl border border-slate-200 bg-slate-50 p-4 text-sm">
      <div className="flex items-start justify-between gap-3">
        <div>
          {result.serviceable ? (
            <p className="font-semibold text-emerald-700 flex items-center gap-1"><CheckCircle2 className="w-4 h-4" /> Delhivery serves this zone</p>
          ) : (
            <p className="font-semibold text-rose-700 flex items-center gap-1"><XCircle className="w-4 h-4" /> Not serviceable: {result.message}</p>
          )}
          <p className="text-xs text-slate-500 mt-1">
            Test trip from {result.pickup?.lat?.toFixed(4)}, {result.pickup?.lng?.toFixed(4)} to {result.drop?.lat?.toFixed(4)}, {result.drop?.lng?.toFixed(4)}
          </p>
        </div>
        <button onClick={onClose} className="p-1 rounded hover:bg-slate-200"><X className="w-4 h-4" /></button>
      </div>
      {result.serviceable && (
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-xs">
            <thead><tr className="text-left text-slate-500"><th className="py-1 pr-4">Vehicle</th><th className="pr-4">Fare</th><th className="pr-4">Pickup in</th><th className="pr-4">Delivery in</th><th>Distance</th></tr></thead>
            <tbody>
              {(result.vehicles || []).filter(Boolean).map((v) => (
                <tr key={v.vehicleMode} className={v.vehicleMode === result.selected?.vehicleMode ? "font-semibold text-slate-900" : "text-slate-700"}>
                  <td className="py-1 pr-4">{v.vehicleMode}{v.vehicleMode === result.selected?.vehicleMode ? " (selected)" : ""}</td>
                  <td className="pr-4">{rupees(v.fare)}</td>
                  <td className="pr-4">{v.pickupTatSec ? `${Math.round(v.pickupTatSec / 60)} min` : "—"}</td>
                  <td className="pr-4">{v.deliveryTatSec ? `${Math.round(v.deliveryTatSec / 60)} min` : "—"}</td>
                  <td>{v.distanceKm ? `${v.distanceKm.toFixed(1)} km` : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

function Shipments({ refreshKey, onChanged }) {
  const [view, setView] = useState("active")
  const [search, setSearch] = useState("")
  const [query, setQuery] = useState("")
  const [data, setData] = useState({ items: [], total: 0 })
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState({})

  const load = useCallback(async () => {
    try {
      setLoading(true)
      const res = await adminAPI.getDeliveryShipments({ view, search: query, limit: 50 })
      setData(res?.data?.data || { items: [], total: 0 })
    } catch (err) {
      toast.error(errMsg(err, "Could not load shipments"))
    } finally {
      setLoading(false)
    }
  }, [view, query])

  useEffect(() => { load() }, [load, refreshKey])

  const act = async (key, fn, success) => {
    if (busy[key]) return
    try {
      setBusy((b) => ({ ...b, [key]: true }))
      await fn()
      toast.success(success)
      await load()
      onChanged?.()
    } catch (err) {
      toast.error(errMsg(err, "Action failed"))
    } finally {
      setBusy((b) => ({ ...b, [key]: false }))
    }
  }

  const cancel = (s) => {
    const reason = window.prompt(
      `Cancel Delhivery booking ${s.providerOrderId || ""}?\nReason (one of):\n${CANCEL_REASONS.join("\n")}`,
      CANCEL_REASONS[0],
    )
    if (reason === null) return
    act(`c-${s.id}`, () => adminAPI.cancelDeliveryShipment(s.id, reason), "Booking cancelled")
  }

  return (
    <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 mb-4">
        <h2 className="text-lg font-bold text-slate-900">Delhivery shipments</h2>
        <div className="flex flex-wrap items-center gap-2">
          {[["active", "Active"], ["attention", "Needs attention"], ["all", "All"]].map(([v, t]) => (
            <button key={v} onClick={() => setView(v)} className={`px-3 py-1.5 rounded-lg text-sm font-semibold ${view === v ? "bg-slate-900 text-white" : "bg-slate-100 text-slate-700 hover:bg-slate-200"}`}>{t}</button>
          ))}
          <form onSubmit={(e) => { e.preventDefault(); setQuery(search.trim()) }} className="relative">
            <Search className="w-4 h-4 absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
            <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Order, CRN or restaurant" className="pl-8 pr-3 py-1.5 text-sm rounded-lg border border-slate-300 w-56" />
          </form>
          <button onClick={load} className="p-2 rounded-lg hover:bg-slate-100" title="Refresh"><RefreshCw className="w-4 h-4" /></button>
        </div>
      </div>

      {view === "attention" && (
        <p className="text-xs text-slate-600 bg-amber-50 border border-amber-200 rounded-lg p-3 mb-4">
          Orders meant for Delhivery that have no live booking — usually no rider was found twice. Send again, hand to own riders, or cancel the order from Orders.
        </p>
      )}

      {loading ? (
        <div className="py-16 text-center"><Loader2 className="w-6 h-6 animate-spin inline text-slate-400" /></div>
      ) : data.items.length === 0 ? (
        <div className="py-16 text-center text-sm text-slate-500">Nothing here.</div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-slate-50 border-b border-slate-200">
              <tr className="text-left text-xs font-bold text-slate-600 uppercase tracking-wider">
                <th className="px-3 py-3">Order</th>
                <th className="px-3 py-3">Delhivery</th>
                <th className="px-3 py-3">Status</th>
                <th className="px-3 py-3">Rider</th>
                <th className="px-3 py-3">Fare</th>
                <th className="px-3 py-3">Created</th>
                <th className="px-3 py-3">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {data.items.map((s) => (
                <tr key={s.id || s.orderId} className="align-top">
                  <td className="px-3 py-3">
                    <p className="font-semibold text-slate-900">{s.order?.orderNumber}</p>
                    <p className="text-xs text-slate-500">{s.order?.restaurantName} · {s.order?.zoneName}</p>
                    <p className="text-xs text-slate-500">Order: {s.order?.orderStatus?.replace(/_/g, " ")}</p>
                  </td>
                  <td className="px-3 py-3">
                    <p className="font-mono text-xs">{s.providerOrderId || "—"}</p>
                    {s.trackingUrl && (
                      <a href={s.trackingUrl} target="_blank" rel="noreferrer" className="text-xs text-blue-600 hover:underline inline-flex items-center gap-1">Track <ExternalLink className="w-3 h-3" /></a>
                    )}
                  </td>
                  <td className="px-3 py-3">
                    <Badge className={FULFILMENT_STYLE[s.fulfilmentStatus] || "bg-slate-100 text-slate-700"}>{(s.fulfilmentStatus || "—").replace(/_/g, " ")}</Badge>
                    {!s.active && <p className="text-[11px] text-slate-500 mt-1">closed</p>}
                    {s.active && !s.readyToShip && s.confirmDueAt && <p className="text-[11px] text-amber-700 mt-1">rider held until {new Date(s.confirmDueAt).toLocaleTimeString()}</p>}
                    {(s.failureReason || s.cancellationReason) && (
                      <p className="text-[11px] text-rose-700 mt-1 max-w-[220px]">{s.failureReason || s.cancellationReason}</p>
                    )}
                  </td>
                  <td className="px-3 py-3 text-xs">
                    {s.riderName ? (
                      <>
                        <p className="font-semibold text-slate-900">{s.riderName}</p>
                        <p className="text-slate-500">{s.vehicleNumber || ""}</p>
                        {s.riderPhone && <p className="text-slate-500">{s.riderPhone}</p>}
                      </>
                    ) : "—"}
                  </td>
                  <td className="px-3 py-3 text-xs">
                    <p>Quote {rupees(s.quotedFare)}</p>
                    {s.finalFare !== null && s.finalFare !== undefined && <p className="font-semibold">Final {rupees(s.finalFare)}</p>}
                  </td>
                  <td className="px-3 py-3 text-xs text-slate-500">{when(s.createdAt)}</td>
                  <td className="px-3 py-3">
                    <div className="flex flex-col gap-1.5 min-w-[140px]">
                      {s.id && s.providerOrderId && (
                        <button onClick={() => act(`r-${s.id}`, () => adminAPI.resyncDeliveryShipment(s.id), "Synced")} className="text-xs font-semibold text-slate-700 hover:underline text-left">
                          {busy[`r-${s.id}`] ? "Syncing…" : "Sync now"}
                        </button>
                      )}
                      {s.active && (
                        <button onClick={() => cancel(s)} className="text-xs font-semibold text-rose-600 hover:underline text-left">Cancel booking</button>
                      )}
                      {!s.active && !["delivered"].includes(s.order?.orderStatus) && !String(s.order?.orderStatus || "").startsWith("cancelled") && (
                        <button onClick={() => act(`t-${s.orderId}`, () => adminAPI.retryDeliveryForOrder(s.orderId), "Sent to Delhivery again")} className="text-xs font-semibold text-blue-600 hover:underline text-left">
                          {busy[`t-${s.orderId}`] ? "Sending…" : "Send to Delhivery again"}
                        </button>
                      )}
                      {!["delivered"].includes(s.order?.orderStatus) && !String(s.order?.orderStatus || "").startsWith("cancelled") && (
                        <button
                          onClick={() => window.confirm("Cancel the Delhivery booking (if any) and hand this order to our own riders?") &&
                            act(`o-${s.orderId}`, () => adminAPI.switchOrderToOwnRiders(s.orderId), "Handed to own riders")}
                          className="text-xs font-semibold text-slate-700 hover:underline text-left"
                        >
                          {busy[`o-${s.orderId}`] ? "Switching…" : "Switch to own riders"}
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="text-xs text-slate-500 mt-3">{data.total} total</p>
        </div>
      )}
    </div>
  )
}

export default function DeliveryProviders() {
  const [overview, setOverview] = useState(null)
  const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState(null)
  const [testing, setTesting] = useState({})
  const [quotes, setQuotes] = useState({})
  const [checking, setChecking] = useState(false)
  const [credential, setCredential] = useState(null)
  const [refreshKey, setRefreshKey] = useState(0)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      const res = await adminAPI.getDeliveryProviders()
      setOverview(res?.data?.data || null)
    } catch (err) {
      toast.error(errMsg(err, "Could not load delivery providers"))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { load() }, [load])

  const provider = overview?.provider
  const zones = useMemo(() => overview?.zones || [], [overview])

  const checkCredentials = async () => {
    try {
      setChecking(true)
      const res = await adminAPI.checkDeliveryProviderCredentials()
      setCredential(res?.data?.data || null)
    } catch (err) {
      setCredential({ ok: false, message: errMsg(err, "Check failed") })
    } finally {
      setChecking(false)
    }
  }

  const testZone = async (zone) => {
    try {
      setTesting((t) => ({ ...t, [zone.zoneId]: true }))
      const res = await adminAPI.testZoneDeliveryQuote(zone.zoneId)
      setQuotes((q) => ({ ...q, [zone.zoneId]: res?.data?.data }))
    } catch (err) {
      toast.error(errMsg(err, "Test failed"))
    } finally {
      setTesting((t) => ({ ...t, [zone.zoneId]: false }))
    }
  }

  return (
    <div className="p-4 lg:p-6 bg-slate-50 min-h-screen">
      <div className="max-w-7xl mx-auto space-y-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-red-600 flex items-center justify-center"><Truck className="w-5 h-5 text-white" /></div>
          <div>
            <h1 className="text-2xl font-bold text-slate-900">Delivery Providers</h1>
            <p className="text-sm text-slate-500">Hand deliveries to Delhivery Local, zone by zone. Zones left alone keep using your own riders.</p>
          </div>
        </div>

        {loading && !overview ? (
          <div className="py-16 text-center"><Loader2 className="w-6 h-6 animate-spin inline text-slate-400" /></div>
        ) : (
          <>
            {/* Connection */}
            <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
              <div className="flex flex-col lg:flex-row lg:items-start justify-between gap-4">
                <div className="space-y-2">
                  <h2 className="text-lg font-bold text-slate-900 flex items-center gap-2">
                    Delhivery connection
                    {provider?.configured
                      ? <Badge className="bg-emerald-100 text-emerald-800">credentials set</Badge>
                      : <Badge className="bg-rose-100 text-rose-800">not configured</Badge>}
                    <Badge className={provider?.env === "production" ? "bg-red-100 text-red-800" : "bg-amber-100 text-amber-800"}>{provider?.env}</Badge>
                  </h2>
                  {!provider?.configured && (
                    <p className="text-sm text-slate-600">
                      Add <code className="bg-slate-100 px-1 rounded">DELHIVERY_CLIENT_ID</code>, <code className="bg-slate-100 px-1 rounded">DELHIVERY_CLIENT_SECRET</code> and <code className="bg-slate-100 px-1 rounded">DELHIVERY_CLIENT_CODE</code> to the server's Backend/.env. Until then nothing is sent to Delhivery, even in enabled zones.
                    </p>
                  )}
                  <p className="text-xs text-slate-500">API: {provider?.baseUrl}</p>
                  <p className="text-xs text-slate-500">
                    Webhook URL (sent to Delhivery automatically): {provider?.webhookUrl || <span className="text-rose-600">set PUBLIC_API_BASE_URL</span>}
                    {" · "}webhook key {provider?.webhookKeySet ? "set" : <span className="text-rose-600">missing (DELHIVERY_WEBHOOK_API_KEY)</span>}
                  </p>
                  {credential && (
                    <p className={`text-sm font-medium flex items-center gap-1 ${credential.ok ? "text-emerald-700" : "text-rose-700"}`}>
                      {credential.ok ? <CheckCircle2 className="w-4 h-4" /> : <XCircle className="w-4 h-4" />} {credential.message}
                    </p>
                  )}
                </div>
                <div className="flex gap-3 items-center">
                  <div className="text-center px-4 py-2 rounded-xl bg-slate-50 border border-slate-200">
                    <p className="text-2xl font-bold text-slate-900">{overview?.counts?.active ?? 0}</p>
                    <p className="text-xs text-slate-500">active</p>
                  </div>
                  <div className={`text-center px-4 py-2 rounded-xl border ${overview?.counts?.attention ? "bg-amber-50 border-amber-200" : "bg-slate-50 border-slate-200"}`}>
                    <p className="text-2xl font-bold text-slate-900 flex items-center justify-center gap-1">
                      {overview?.counts?.attention ? <AlertTriangle className="w-5 h-5 text-amber-600" /> : null}{overview?.counts?.attention ?? 0}
                    </p>
                    <p className="text-xs text-slate-500">need attention</p>
                  </div>
                  <button onClick={checkCredentials} disabled={checking || !provider?.configured} className="px-4 py-2 rounded-lg bg-slate-900 text-white text-sm font-semibold disabled:opacity-50 inline-flex items-center gap-2">
                    {checking && <Loader2 className="w-4 h-4 animate-spin" />} Test connection
                  </button>
                </div>
              </div>
            </div>

            {/* Zones */}
            <div className="bg-white rounded-xl shadow-sm border border-slate-200 p-6">
              <h2 className="text-lg font-bold text-slate-900 mb-1">Zones</h2>
              <p className="text-xs text-slate-500 mb-4">An order follows its restaurant's zone (that is where the rider picks up).</p>
              <div className="space-y-3">
                {zones.map((z) => (
                  <div key={z.zoneId} className="rounded-xl border border-slate-200 p-4">
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
                      <div>
                        <p className="font-semibold text-slate-900 flex items-center gap-2">
                          {z.zoneName}
                          {!z.zoneActive && <Badge className="bg-slate-100 text-slate-600">zone inactive</Badge>}
                          {z.isEnabled && z.mode !== "own"
                            ? <Badge className="bg-red-100 text-red-800">{label(MODES, z.mode)}</Badge>
                            : <Badge className="bg-slate-100 text-slate-700">Own riders</Badge>}
                          {z.mode !== "own" && !z.isEnabled && <Badge className="bg-amber-100 text-amber-800">switched off</Badge>}
                        </p>
                        {z.mode !== "own" && (
                          <p className="text-xs text-slate-500 mt-1">
                            {z.vehicleMode} · {z.assignTimeoutMin} min to find a rider · {label(NO_RIDER, z.onNoRider)} · {label(CONFIRM, z.confirmPolicy)}
                            {z.maxFare ? ` · cap ${rupees(z.maxFare)}` : ""}
                          </p>
                        )}
                      </div>
                      <div className="flex gap-2">
                        <button onClick={() => testZone(z)} disabled={!provider?.configured || testing[z.zoneId]} className="px-3 py-1.5 rounded-lg border border-slate-300 text-sm font-semibold text-slate-700 hover:bg-slate-50 disabled:opacity-50 inline-flex items-center gap-1.5" title={provider?.configured ? "Quote a short trip in this zone" : "Configure credentials first"}>
                          {testing[z.zoneId] ? <Loader2 className="w-4 h-4 animate-spin" /> : <PlayCircle className="w-4 h-4" />} Test with Delhivery
                        </button>
                        <button onClick={() => setEditing(z)} className="px-3 py-1.5 rounded-lg bg-slate-900 text-white text-sm font-semibold inline-flex items-center gap-1.5">
                          <Pencil className="w-4 h-4" /> Settings
                        </button>
                      </div>
                    </div>
                    <QuoteResult result={quotes[z.zoneId]} onClose={() => setQuotes((q) => ({ ...q, [z.zoneId]: null }))} />
                  </div>
                ))}
                {zones.length === 0 && <p className="text-sm text-slate-500">No zones yet. Create one under Zone Setup first.</p>}
              </div>
            </div>

            <Shipments refreshKey={refreshKey} onChanged={load} />
          </>
        )}
      </div>

      {editing && (
        <ZoneConfigModal
          zone={editing}
          vehicleModes={overview?.vehicleModes || ["2-wheeler"]}
          onClose={() => setEditing(null)}
          onSaved={() => { setEditing(null); load(); setRefreshKey((k) => k + 1) }}
        />
      )}
    </div>
  )
}
