package di
import std.sync.{Mutex}
import std.ref.{WeakRef, CleanupPolicy}
public class ServiceLazyClass<T> <: Service<T> where T <: Object {
    let mu = Mutex()
    let _name:String
    var instance:Option<WeakRef<T>> = None
    let pvd:Provider<T>
    public prop name:String {
        get() {
            this._name
        }
    }
    public init(name:String, pvd:Provider<T>) {
        this._name = name
        this.pvd = pvd
    }
    public func getInstance(injector:Injector):Option<T> {
        synchronized(this.mu){
            if (let Some(v) <- this.instance) {
                if (v.value.isNone()) {
                    this.build(injector)
                }
                return v.value
            }
            return None
        }
    }
    private func build(injector:Injector): Bool {
       let result = this.pvd(injector)
        if (let Some(v) <- result) {
            this.instance = WeakRef<T>(v, CleanupPolicy.DEFERRED)
            return true
        }
        return false
    }
    public func healthcheck():HealthState {
        synchronized(this.mu) {
            if (this.instance?.value.isSome() ?? false) {
                return HealthState.Health
            }
            let inst = this.instance.getOrThrow()
            match (inst) {
                case v:healthcheckableService => v.healthcheck()
                case _ => HealthState.UnSupport
            }
        }
    }
    public func shutdown():ShutdownState {
        synchronized(this.mu) {
            if (this.instance.isNone()) {
                return ShutdownState.Shutdowned
            }
            let inst = this.instance.getOrThrow()
            match (inst) {
                case v:ShutdownableService => 
                    this.instance?.clear()
                    v.shutdown()
                case _ => ShutdownState.UnSupport
            }
        }
    }
    public func clone():Any {
        return ServiceLazy<T>(this.name, this.pvd)
    }
}  
