package di

import std.sync.{Mutex}
import std.ref.{WeakRef, CleanupPolicy}

public class ServiceLazyClass<T> <: Service<T> where T <: Object {
    let mu = Mutex()
    let _name: String
    var instance: Option<WeakRef<T>> = None
    let pvd: Provider<T>
    public prop name: String {
        get() {
            this._name
        }
    }
    public init(name: String, pvd: Provider<T>) {
        this._name = name
        this.pvd = pvd
    }
    public func getInstance(injector: Injector): Option<T> {
        synchronized(this.mu) {
            // 如果没有实例或弱引用已被GC回收，则重新构建
            if (this.instance.isNone()) {
                if (!this.build(injector)) {
                    return None
                }
            }
            if (let Some(wr) <- this.instance) {
                if (wr.value.isNone()) {
                    if (!this.build(injector)) {
                        return None
                    }
                }
                return wr.value
            }
            return None
        }
    }
    private func build(injector: Injector): Bool {
        let result = this.pvd(injector)
        if (let Some(v) <- result) {
            this.instance = WeakRef<T>(v, CleanupPolicy.DEFERRED)
            return true
        }
        return false
    }
    public func healthcheck(): HealthState {
        synchronized(this.mu) {
            if (this.instance.isNone()) {
                return HealthState.Health
            }
            if (let Some(inst) <- this.instance) {
                if (inst.value.isNone()) {
                    return HealthState.Health
                }
                if (let Some(v) <- inst.value) {
                    match (v) {
                        case hc: healthcheckableService => hc.healthcheck()
                        case _ => HealthState.UnSupport
                    }
                } else {
                    HealthState.Health
                }
            } else {
                HealthState.Health
            }
        }
    }
    public func shutdown(): ShutdownState {
        synchronized(this.mu) {
            if (this.instance.isNone()) {
                return ShutdownState.Shutdowned
            }
            if (let Some(inst) <- this.instance) {
                if (inst.value.isNone()) {
                    return ShutdownState.Shutdowned
                }
                if (let Some(v) <- inst.value) {
                    match (v) {
                        case sd: ShutdownableService =>
                            inst.clear()
                            sd.shutdown()
                        case _ => ShutdownState.UnSupport
                    }
                } else {
                    ShutdownState.Shutdowned
                }
            } else {
                ShutdownState.Shutdowned
            }
        }
    }
    public func clone(): Any {
        return ServiceLazyClass<T>(this.name, this.pvd)
    }
}
