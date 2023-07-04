package di

public let DefaultInjector = Injector()

extend Injector {
    public prop default:Injector {
        get() {
            return DefaultInjector
        }
    }
    public func provide<T>() where T <: GlobalTypeName & NewInstance<T> {
        this.provide<T>(T.getGlobalTypeName())
    }
    public func provide<T>(name:String) where T <: NewInstance<T> {
        this.provide<T>(name, {i => T.new()})
    }
    public func provide<T>(pvd:Provider<T>) where T <: GlobalTypeName {
        this.provide<T>(T.getGlobalTypeName(), pvd)
    }
    public func provide<T>(name:String, pvd:Provider<T>):Unit {
        if (this.exists(name)) {
            throw Exception("DI: service `${name}` has already been declared")
        }
        let svc = ServiceLazy<T>(name, pvd)
        this.set(name, svc)
        this.log?("service ${name} injected")
    }

    public func provideValue<T>(value:T):Unit where T <: GlobalTypeName {
        provideValue<T>(T.getGlobalTypeName(), value)
    }

    public func provideValue<T>(name:String, value:T):Unit {
        if (this.exists(name)) {
            throw Exception("DI: service `${name}` has already been declared")
        }
        let svc = ServiceEager(name, value)
        this.set(name, svc)
        this.log?("service ${name} injected")
    }

    public func overrideProvider<T>(pvd:Provider<T>):Unit where T <: GlobalTypeName {
        this.overrideProvider<T>(T.getGlobalTypeName(), pvd)
    }

    public func overrideProvider<T>(name:String, pvd:Provider<T>):Unit {
        let svc = ServiceLazy<T>(name, pvd)
        this.set(name, svc)
        this.log?("service ${name} overridden")
    }

    public func overrideValue<T>(value:T) where T <: GlobalTypeName {
        this.overrideValue<T>(T.getGlobalTypeName(), value)
    }

    public func overrideValue<T>(name:String, value:T):Unit {
        let svc = ServiceEager<T>(name, value)
        this.set(name, value)
        this.log?("service ${name} overridden")
    }
    public func invoke<T>():Option<T> where T <: GlobalTypeName  {
        this.invoke<T>(T.getGlobalTypeName())
    }
    public func invoke<T>(name:String):Option<T> {
        let svcAny = this.get(name)
        match (svcAny) {
            case None => return None
            case Some(svc) => 
                match (svc) {
                    case s:Service<T> => 
                    let instance = s.getInstance(this)
                    if (let None = instance) {
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
    public func healthCheck<T>():HealthState where T <: GlobalTypeName{
        return this.healthCheck<T>(T.getGlobalTypeName())
    }

    public func healthCheck<T>(name:String):HealthState {
        return this.healthcheckImplem(name)
    }
    public func shutdown<T>():ShutdownState where T <: GlobalTypeName{
        let name = T.getGlobalTypeName()
        this.shutdownImplem(name)
    }
    public func shutdown<T>(name:String):ShutdownState{
        this.shutdownImplem(name)
    }
}