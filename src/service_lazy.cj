package di

import std.sync.{Mutex}

public type Provider<T> = (Injector) -> Option<T>

public class ServiceLazy<T> <: Service<T> {
    let mu = Mutex()
    let _name: String
    var instance: Option<T> = None
    var built: Bool = false
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
            if (this.built) {
                return this.instance
            }
            if (this.build(injector)) {
                return this.instance
            }
            return None
        }
    }
    private func build(injector: Injector): Bool {
        let result = this.pvd(injector)
        if (let Some(v) <- result) {
            this.instance = result
            this.built = true
            return true
        }
        return false
    }
    public func healthcheck(): HealthState {
        synchronized(this.mu) {
            if (!this.built) {
                return HealthState.Health
            }
            if (let Some(inst) <- this.instance) {
                match (inst) {
                    case v: healthcheckableService => v.healthcheck()
                    case _ => HealthState.UnSupport
                }
            } else {
                HealthState.Health
            }
        }
    }
    public func shutdown(): ShutdownState {
        synchronized(this.mu) {
            if (!this.built) {
                return ShutdownState.Shutdowned
            }
            if (let Some(inst) <- this.instance) {
                match (inst) {
                    case v: ShutdownableService =>
                        this.built = false
                        this.instance = None
                        v.shutdown()
                    case _ => ShutdownState.UnSupport
                }
            } else {
                ShutdownState.Shutdowned
            }
        }
    }
    public func clone(): Any {
        return ServiceLazy<T>(this.name, this.pvd)
    }
}
