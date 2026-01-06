package di_demo

import di.*

// 轮子
class Wheel {
    Wheel(let id: Int64) {}
}

// 引擎接口
interface Engine {}

// 引擎实现
class EngineImplem <: Engine & healthcheckableService {
    public func healthcheck(): HealthState {
        return HealthState.Error("engine broken")
    }
}

// 车的接口
interface Car {
    func start(): Unit
}

// 车的实现
class CarImplem <: Car {
    CarImplem(let engine: Engine, let wheels: Array<Wheel>) {}
    public func start() {
        println("vroooom")
        for (w in this.wheels) {
            println(w.id)
        }
    }
}

// 依赖注入参数的实现
class OptArgs <: InjectorOpts {
    // let logger = SimpleLogger()
    public func hookAfterRegistration(injector: Injector, serviceName: String): Unit {
        println("Service registered: ${serviceName}")
    }
    public func hookAfterShutdown(injector: Injector, serviceName: String): Unit {
        println("Service stopped: ${serviceName}")
    }
    public func log(msg: String): Unit {
        println(msg)
    }
}

class Todo {
    Todo(let name: String) {}
}

main() {
    // let injector = DefaultHasher // 全局默认实例
    // let injector = Injector()    // 无参创建一个实例
    let injector = Injector(OptArgs()) // 使用自定义参数实现

    // 使用类型的全限定名称注册
    injector.provideValue<Wheel>(Wheel(100))
    // 指定注册名称
    injector.provideValue("wheel-1", Wheel(1))
    injector.provideValue("wheel-2", Wheel(2))
    injector.provideValue("wheel-3", Wheel(3))
    injector.provideValue("wheel-4", Wheel(4))
    injector.provide<Car>(
        "Car",
        {
            i =>
                // 获取指定名称的实例
                let wheel1 = i.invoke<Wheel>("wheel-1").getOrThrow()
                let wheel2 = i.invoke<Wheel>("wheel-2").getOrThrow()
                let wheel3 = i.invoke<Wheel>("wheel-3").getOrThrow()
                let wheel4 = i.invoke<Wheel>("wheel-4").getOrThrow()
                let wheel5 = i.invoke<Wheel>().getOrThrow()
                let wheel6 = i.invoke<Wheel>().getOrThrow()
                // 接口类型的泛型参数，只能使用指定名称的方式获取
                let engine = i.invoke<Engine>("Engine").getOrThrow()
                var car = CarImplem(engine, [wheel1, wheel2, wheel3, wheel4, wheel5, wheel6])
                return Some(car)
        }
    )
    // 以命名方式注册接口类型的实现
    injector.provide<Engine>("Engine", {
        _ => return Some(EngineImplem())
    })
    // 使用接口的全限定名注册其实现
    injector.provide<Engine>({
        _ => return Some(EngineImplem())
    })
    // 以指定名称方式获取接口的实现
    let car = injector.invoke<Car>("Car").getOrThrow()
    car.start()

    injector.provideClass<Todo>({_ => Todo("todo")})
    let todo = injector.invoke<Todo>()
    if (let Some(t) <- todo) {
        println("todo name: ${t.name}")
    } else {
        println("todo not found")
    }
    println(injector.listProvidedServices())

    // 检查指定引擎组件的健康状态
    let state = injector.healthCheck<Engine>("Engine")
    println(state)

    // 检查所有组件的健康状态
    let states = injector.healthCheckAll()
    println(states)
}
