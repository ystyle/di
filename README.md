# di
>基于泛型的轻量级依赖注入框架， 移植自go的[`samber/do`](https://github.com/samber/do), 已支持仓颉1.0.0版本

### 特性
- 服务注册
- 服务调用
- 服务关闭
- 服务生命周期勾子(hooks)
- 匿名、命名服务
- 即时或延迟加载
- 依赖图解析
- 针对class的性能优化(使用`Injector.provideClass`方法)
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

## API文档

### Injector类

#### 构造函数
- `Injector()` - 创建默认的注入器
- `Injector(opt: InjectorOpts)` - 使用自定义配置创建注入器

#### 服务注册方法
- `provide<T>()` - 注册类型T的服务（使用默认构造函数）
- `provide<T>(name: String)` - 使用指定名称注册类型T的服务
- `provide<T>(pvd: Provider<T>)` - 使用自定义Provider注册服务
- `provide<T>(name: String, pvd: Provider<T>)` - 使用指定名称和自定义Provider注册服务
- `provideClass<T>()` - 注册类类型T的服务（针对类优化， 使用std.ref让gc自动管理销毁时机，策略为在内存不足时自动回收）
- `provideClass<T>(name: String)` - 使用指定名称注册类类型服务
- `provideClass<T>(pvd: Provider<T>)` - 使用自定义Provider注册类类型服务
- `provideClass<T>(name: String, pvd: Provider<T>)` - 使用指定名称和自定义Provider注册类类型服务
- `provideValue<T>(value: T)` - 注册即时加载的值服务
- `provideValue<T>(name: String, value: T)` - 使用指定名称注册即时加载的值服务

#### 服务覆盖方法
- `overrideProvider<T>(pvd: Provider<T>)` - 覆盖已注册的服务
- `overrideProvider<T>(name: String, pvd: Provider<T>)` - 使用指定名称覆盖服务
- `overrideClass<T>(pvd: Provider<T>)` - 覆盖已注册的服务
- `overrideClass<T>(name: String, pvd: Provider<T>)` - 使用指定名称覆盖服务
- `overrideValue<T>(value: T)` - 覆盖已注册的即时加载值服务
- `overrideValue<T>(name: String, value: T)` - 使用指定名称覆盖即时加载值服务

#### 服务调用方法
- `invoke<T>(): Option<T>` - 获取类型T的服务实例
- `invoke<T>(name: String): Option<T>` - 获取指定名称的服务实例

#### 健康检查方法
- `healthCheck<T>(): HealthState` - 检查类型T的服务健康状态
- `healthCheck<T>(name: String): HealthState` - 检查指定名称服务的健康状态
- `healthCheckAll(): HashMap<String, HealthState>` - 检查所有注册服务的健康状态

#### 服务关闭方法
- `shutdown<T>(): ShutdownState` - 关闭类型T的服务
- `shutdown<T>(name: String): ShutdownState` - 关闭指定名称的服务
- `shutdownAll(): ShutdownState` - 关闭所有服务

#### 服务查询方法
- `listProvidedServices(): Array<String>` - 获取所有已注册服务的名称列表
- `listInvokedServices(): Array<String>` - 获取所有已调用服务的名称列表

#### 实用方法
- `cloneWithOpts(opt: InjectorOpts): Injector` - 克隆注入器并应用新配置

### 全局实例
- `DefaultInjector` - 默认的全局注入器实例

### 接口定义
- `NewInstance<T>` - 用于定义无参构造的接口
- `healthcheckableService` - 健康检查接口，定义`healthcheck():HealthState`方法
- `ShutdownableService` - 关闭服务接口，定义`shutdown():ShutdownState`方法
- `InjectorOpts` - 注入器配置接口，定义hooks和日志回调
