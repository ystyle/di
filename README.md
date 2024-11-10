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
- 默认依赖注入容器(let injector = DefaultInjector)
- 容器克隆(clone)
- 服务覆盖

>服务按调用顺序加载

### 快速开始

引入
```toml
[dependencies]
  di = { git = "https://github.com/ystyle/di", branch = "master"}
```

初始化容器
```cj
import di.*

main():Unit {
    let injector = Injector()
    // 使用类型全限定名注册
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
class CarService <: ShutdownableService {
    CarService(let engine:EngineService){}

    public func start() {
        println("car starting")
    }
    public func shutdown():ShutdownState {
        println("car stopped")
        return ShutdownState.Shutdowned
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
获取默认容器： `let injector = DefaultInjector`

#### 获取已注册的服务
```
DefaultInjector.listProvidedServices()
DefaultInjector.listInvokedServices()
```

### 注册服务
延迟加载
```cj
class DBService  {
    DBService(let db:sql.connect){}
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
class Config {
    Config(let name:String){}
}

DefaultInjector.provideValue<Config>(Config("test"))
DefaultInjector.provideValue<Config>("Config", Config("test"))
```

### 获取服务
```cj
injector.invoke<DBService>()
injector.invoke<Config>("Config")
```

### 健康检查
```
class DBService <: healthcheckableService  {
    DBService(let db:sql.connect){}

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
class DBService <: healthcheckableService  {
    DBService(let db:sql.connect){}
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
injector.invoke<Config>("Config")
```

### 接口
```
// 用于代替无参构建方法, 之后可以直接`injector.invoke<CustomType>()`, injector.invoke<CustomType>("CustomType") 注册
public interface NewInstance<T> {
    static func new():T
}
// 自定义健康检查方法
public interface healthcheckableService {
    func healthcheck():HealthState
}
// 自定义关闭服务方法，比如关闭 数据库连接， 调用shutdown时会调用该方法
public interface ShutdownableService {
    func shutdown():ShutdownState
}
```