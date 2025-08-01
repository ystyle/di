package di

import std.reflect.TypeInfo

public let DefaultInjector = Injector()

extend Injector {
    public func provide<T>(): Unit where T <: NewInstance<T> {
        this.provide<T>(TypeInfo.of<T>().qualifiedName)
    }
    public func provide<T>(name: String): Unit where T <: NewInstance<T> {
        this.provide<T>(name, {_ => T.new()})
    }
    public func provide<T>(pvd: Provider<T>): Unit {
        this.provide<T>(TypeInfo.of<T>().qualifiedName, pvd)
    }
    public func provide<T>(name: String, pvd: Provider<T>): Unit {
        if (this.exists(name)) {
            throw Exception("DI: service `${name}` has already been declared")
        }
        let svc = ServiceLazy<T>(name, pvd)
        this.set(name, svc)
        this.log?("service ${name} injected")
    }
    public func provideClass<T>(): Unit where T <: NewInstance<T> & Object {
        this.provideClass<T>(TypeInfo.of<T>().qualifiedName)
    }
    public func provideClass<T>(name: String): Unit where T <: NewInstance<T> & Object {
        this.provideClass<T>(name, {_ => T.new()})
    }
    public func provideClass<T>(pvd: Provider<T>): Unit where T <: Object{
        this.provideClass<T>(TypeInfo.of<T>().qualifiedName, pvd)
    }
    public func provideClass<T>(name: String, pvd: Provider<T>): Unit where T <: Object {
        if (this.exists(name)) {
            throw Exception("DI: service `${name}` has already been declared")
        }
        let svc = ServiceLazyClass<T>(name, pvd)
        this.set(name, svc)
        this.log?("service ${name} injected")
    }

    public func provideValue<T>(value: T): Unit {
        provideValue<T>(TypeInfo.of<T>().qualifiedName, value)
    }

    public func provideValue<T>(name: String, value: T): Unit {
        if (this.exists(name)) {
            throw Exception("DI: service `${name}` has already been declared")
        }
        let svc = ServiceEager(name, value)
        this.set(name, svc)
        this.log?("service ${name} injected")
    }

    public func overrideProvider<T>(pvd: Provider<T>): Unit {
        this.overrideProvider<T>(TypeInfo.of<T>().qualifiedName, pvd)
    }

    public func overrideProvider<T>(name: String, pvd: Provider<T>): Unit {
        let svc = ServiceLazy<T>(name, pvd)
        this.set(name, svc)
        this.log?("service ${name} overridden")
    }

    public func overrideClass<T>(pvd: Provider<T>): Unit where T <: Object{
        this.overrideClass<T>(TypeInfo.of<T>().qualifiedName, pvd)
    }

    public func overrideClass<T>(name: String, pvd: Provider<T>): Unit where T <: Object {
        let svc = ServiceLazyClass<T>(name, pvd)
        this.set(name, svc)
        this.log?("service ${name} overridden")
    }

    public func overrideValue<T>(value: T): Unit {
        this.overrideValue<T>(TypeInfo.of<T>().qualifiedName, value)
    }

    public func overrideValue<T>(name: String, value: T): Unit {
        let svc = ServiceEager<T>(name, value)
        this.set(name, svc)
        this.log?("service ${name} overridden")
    }
    public func invoke<T>(): Option<T> {
        this.invoke<T>(TypeInfo.of<T>().qualifiedName)
    }
    public func invoke<T>(name: String): Option<T> {
        let svcAny = this.get(name)
        match (svcAny) {
            case None => return None
            case Some(svc) => match (svc) {
                case s: Service<T> =>
                    let instance = s.getInstance(this)
                    if (let None <- instance) {
                        return None
                    }
                    this.onServiceInvoke(name)
                    this.log?("service ${name} invoked")
                    return instance
                case _ =>
                    this.log?(this.serviceNotFound(name).message)
                    return None
            }
        }
    }
    public func healthCheck<T>(): HealthState {
        return this.healthCheck<T>(TypeInfo.of<T>().qualifiedName)
    }

    public func healthCheck<T>(name: String): HealthState {
        return this.healthcheckImplem(name)
    }
    public func shutdown<T>(): ShutdownState {
        this.shutdownImplem(TypeInfo.of<T>().qualifiedName)
    }
    public func shutdown<T>(name: String): ShutdownState {
        this.shutdownImplem(name)
    }
}
