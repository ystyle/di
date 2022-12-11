package di

public interface Service<T> <: healthcheckableService & ShutdownableService & CloneableService {
    prop let name:String
    func getInstance(injector:Injector):Option<T>
}

public interface healthcheckableService {
    func healthcheck():HealthState
}

public enum HealthState <: ToString {
    UnSupport | Health | Error(String)
    public func toString():String {
        match (this) {
            case UnSupport => "UnSupport"
            case Health => "Health"
            case Error(msg) => msg
        }
    }
}

public interface ShutdownableService {
    func shutdown():ShutdownState
}

public enum ShutdownState <: ToString {
    UnSupport | Shutdowned | Error(String)
    public func toString():String {
        match (this) {
            case UnSupport => "UnSupport"
            case Shutdowned => "Shutdowned"
            case Error(msg) => msg
        }
    }
}

public interface CloneableService{
    func clone():Any
}