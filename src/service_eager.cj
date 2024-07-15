package di

public struct ServiceEager<T> <: Service<T>{
    let instance:T
    let _name:String
    public prop name:String {
        get() {
            return this._name
        }
    }
    public init(name:String, instance:T) {
        this._name = name
        this.instance = instance
    }
    public func getInstance(injector:Injector):Option<T> {
        return this.instance
    }
    public func healthcheck():HealthState {
        match (this.instance) {
            case v:healthcheckableService => v.healthcheck()
            case _ => HealthState.UnSupport
        }
    }
    public func shutdown():ShutdownState {
         match (this.instance) {
            case v:ShutdownableService => v.shutdown()
            case _ => ShutdownState.UnSupport
        }
    }
    public func clone():Any {
        let v = this
        return v
    }
}