# di
>基于泛型的轻量级依赖注入框架， 移植自go的[`samber/do`](https://github.com/samber/do)

### 特性
- 服务注册
- 服务调用
- 服务关闭
- 服务生命周期勾子(hooks)
- 匿名、命名服务
- 即时或延迟加载
- 依赖图解析
- 默认依赖注入容器(let DefaultInjector = Injector())
- 容器克隆(clone)
- 服务覆盖

>服务按调用顺序加载

### 快速开始
初始化容器
```cj
from di import di.*

main():Unit {
    let injector = Injector()
    // 实现GlobalTypeName接口的类型， 可以直接以T.getGlobalTypeName()为名称注册
    injector.provide<CarService>(NewCarService)
    // intetface 类型需要指定名称
    injector.provide<EngineService>("EngineService", NewEngineService)

    // 获取CarService
    let car = injector.invoke<CarService>().getOrThrow()
    car.start()

    // 健康检查
    let state = injector.healthCheck<EngineService>("EngineService")
    println(state)
    
    // 关闭服务
    injector.shutdown()
}
```

服务
```cj
interface EngineService {

}

class EngineServiceImplem  <: EngineService & healthcheckableService {
    public func healthcheck():HealthState {
        return HealthState.Error("engine broken")
    }
}

func NewEngineService(injector:Injector):Option<EngineService> {
    return Some(EngineServiceImplem())
}
```

```
class CarService <: ShutdownableService & GlobalTypeName {
    CarService(let engine:EngineService){}

    public func start() {
        println("car starting")
    }
    public func shutdown():ShutdownState {
        println("car stopped")
        return ShutdownState.Shutdowned
    }

    public static func getGlobalTypeName():String {
        return "CarService"
    }
}

func NewCarService (injector:Injector):Option<CarService> {
    let engine = injector.invoke<EngineService>("EngineService").getOrThrow()
    let car = CarService(engine)
    return Some(car)
}
```

#### 初始化容器
```cj
let injector = Injector()
```
获取默认容器： `DefaultInjector` 或者  `let injector = Injector.default`

#### 获取已注册的服务
```
DefaultInjector.listProvidedServices()
DefaultInjector.listInvokedServices()
```

### 注册服务
延迟加载
```cj
class DBService <: GlobalTypeName  {
    DBService(let db:sql.connect){}
    public static func getGlobalTypeName():String {
        return "DBService"
    }
}

DefaultInjector.provide<DBService>({injector => {
    let db = sql.open(...)
    // ...
    return Some(DBService(db))
}})
```

指定命名注册
```cj
DefaultInjector.provide<DBService>("db_connect", {injector => {
    let db = sql.open(...)
    // ...
    return Some(DBService(db))
}})
```

即时加载
```cj
class Config <: GlobalTypeName {
    Config(let name:String){}
    public static func getGlobalTypeName():String {
        return "Config"
    }
}

DefaultInjector.provideValue<Config>(Config("test"))
DefaultInjector.provideValue<Config>("Config", Config("test"))
```

### 获取服务
```cj
injector.invoke<DBService>()
injector.invokeName<Config>("Config")
```

### 健康检查
```
class DBService <: GlobalTypeName & healthcheckableService  {
    DBService(let db:sql.connect){}
    public static func getGlobalTypeName():String {
        return "DBService"
    }
    // 自定义健康检查方法
    public func healthcheck():HealthState {
        let pong = this.db.ping()
        if (pong != "pong") {
            return HealthState.Error("Error: db disconnect")
        }
        return HealthState.Health
    }
}

DefaultInjector.provide<DBService>({injector => {
    let db = sql.open(...)
    // ...
    return Some(DBService(db))
}})
let state = DefaultInjector.healthCheck<DBService>
println(state)
```

### 关闭服务
```cj
class DBService <: GlobalTypeName & healthcheckableService  {
    DBService(let db:sql.connect){}
    public static func getGlobalTypeName():String {
        return "DBService"
    }
}

DefaultInjector.provide<DBService>({injector => {
    let db = sql.open(...)
    // ...
    return Some(DBService(db))
}})
DefaultInjector.shutdown<DBService>()
DefaultInjector.shutdown<DBService>("db_connect")
```

### 服务覆盖
```cj
DefaultInjector.provide<DBService>({injector => {
    let db = sql.open(...)
    // ...
    return Some(DBService(db))
}})
DefaultInjector.overrideProvider<DBService>({injector => {
    let db = sql.open(...)
    // ...
    return Some(DBService(db))
}})
```

### Hooks
>实现`InjectorOpts`接口，可以定义注册后，关闭后和打印日志的回调勾子
```
class OptArgs <: InjectorOpts {
    let logger = SimpleLogger()
    public func hookAfterRegistration(injector:Injector, serviceName:String):Unit {
        println("Service registered: ${serviceName}")
    }
    public func hookAfterShutdown(injector:Injector, serviceName:String):Unit {
        println("Service stopped: ${serviceName}")
    }
    public func log(msg:String):Unit {
       logger.info(msg)
    }
}
let injector = Injector(OptArgs())
```

### clone
>注册的服务， 由provide注册的，复制将变回未加载状态; provideValue注册的将复制一个一样的
```cj
let injector = DefaultInjector.clone()
injector.invokeName<Config>("Config")
```