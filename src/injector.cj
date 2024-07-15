package di

import std.sync.ReentrantMutex
import std.collection.HashMap

public interface InjectorOpts {
    func hookAfterRegistration(injector: Injector, serviceName: String): Unit
    func hookAfterShutdown(injector: Injector, serviceName: String): Unit
    func log(msg: String): Unit
}

public class DefaultOptArgs <: InjectorOpts {
    public func hookAfterRegistration(injector:Injector, serviceName:String):Unit {
    }
    public func hookAfterShutdown(injector:Injector, serviceName:String):Unit {
    }
    public func log(msg:String):Unit {
    }
}

public class Injector {
    let mu = ReentrantMutex()
    let services = HashMap<String, Any>()
    let orderedInvocation = HashMap<String, Int64>()
    var orderedInvocationIndex: Int64 = 0
    var hookAfterRegistration: Option<(Injector, String) -> Unit> = None
    var hookAfterShutdown: Option<(Injector, String) -> Unit> = None
    var log: Option<(String) -> Unit> = None
    public init() {
    }

    public init(opt: InjectorOpts) {
        this.hookAfterRegistration = opt.hookAfterRegistration
        this.hookAfterShutdown = opt.hookAfterShutdown
        this.log = opt.log
        this.log?("injector created")
    }

    public func listProvidedServices(): Array<String> {
        var names = Array<String>()
        synchronized(this.mu) {
            names = this.services.keys().toArray()
        }
        this.log?("exported list of services: ${names}")
        return names
    }
    public func listInvokedServices(): Array<String> {
        var names = Array<String>()
        synchronized(this.mu) {
            names = this.orderedInvocation.keys().toArray()
        }
        this.log?("exported list of services: ${names}")
        return names
    }
    public func healthCheckAll(): HashMap<String, HealthState> {
        let names: Array<String> = this.listProvidedServices()
        this.log?("requested healthcheck")
        let results = HashMap<String, HealthState>()
        for (name in names) {
            results[name] = this.healthcheckImplem(name)
        }
        this.log?("got healthcheck results: ${results}")
        return results
    }
    func healthcheckImplem(name: String): HealthState {
        let service: Any
        synchronized(this.mu) {
            let opt = this.services.get(name)
            if (let None <- opt) {
                this.log?("DI: could not find service `${name}`")
                return HealthState.Error("DI: could not find service `${name}`")
            }
            service = opt.getOrThrow()
        }
        match (service) {
            case svc: healthcheckableService => svc.healthcheck()
            case _ => HealthState.UnSupport
        }
    }
    public func shutdownAll(): ShutdownState {
        var m: HashMap<String, Int64>
        synchronized(this.mu) {
            m = this.orderedInvocation
        }
        this.log?("requested shutdown")
        let keys = m.keys().toArray()
        for (key in keys) {
            let result = this.shutdownImplem(key)
            if (let Error(msg) <- result) {
                return result
            }
        }
        this.log?("shutdowned services")
        return ShutdownState.Shutdowned
    }
    func shutdownImplem(name: String): ShutdownState {
        var svc: Any
        synchronized(this.mu) {
            let opt = this.services.get(name)
            if (let Some(v) <- opt) {
                svc = v
            } else {
                return ShutdownState.Error("DI: could not find service `${name}`")
            }
        }
        var result = match (svc) {
            case v: ShutdownableService =>
                this.log?("requested shutdown for service ${name}")
                v.shutdown()
            case _ => ShutdownState.UnSupport
        }
        this.services.remove(name)
        this.orderedInvocation.remove(name)
        this.onServiceShutdown(name)
        return result
    }

    func exists(name: String): Bool {
        synchronized(this.mu) {
            return this.services.contains(name)
        }
    }
    func get(name: String): Option<Any> {
        synchronized(this.mu) {
            return this.services.get(name)
        }
    }
    func set(name: String, svc: Any): Unit {
        synchronized(this.mu) {
            this.services[name] = svc
        }
        this.onServiceRegistration(name)
    }
    func remove(name: String): Unit {
        synchronized(this.mu) {
            this.services.remove(name)
        }
    }
    func forEach(fn: (String, Any) -> Unit) {
        synchronized(this.mu) {
            for ((name, svc) in this.services) {
                fn(name, svc)
            }
        }
    }
    func serviceNotFound(name: String): Exception {
        let names: Array<String> = this.services.keys().toArray()
        return Exception("DI: could not find service `${name}`, available services: ${names}")
    }
    func onServiceInvoke(name: String) {
        if (!this.orderedInvocation.contains(name)) {
            this.orderedInvocation[name] = this.orderedInvocationIndex
            this.orderedInvocationIndex += 1
        }
    }
    func onServiceRegistration(name: String) {
        this.hookAfterRegistration?(this, name)
    }
    func onServiceShutdown(name: String) {
        this.hookAfterShutdown?(this, name)
    }
    public func cloneWithOpts(opt: InjectorOpts): Injector {
        let injector = Injector(opt)
        synchronized(this.mu) {
            for ((key, svc) in this.services) {
                match (svc) {
                    case v: CloneableService => injector.services[key] = v.clone()
                    case _ => injector.services[key] = svc
                }
                injector.onServiceRegistration(key)
            }
        }
        this.log?("injector cloned")
        return injector
    }
}
