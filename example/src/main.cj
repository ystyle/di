from di import di.*
from std import log.*

class Wheel <: GlobalTypeName {
    Wheel(let id:Int64){}
    public static func getGlobalTypeName():String {
        return "Wheel"
    }
}

interface Engine {

}

class EngineImplem  <: Engine & healthcheckableService {
    public func healthcheck():HealthState {
        return Error("engine broken")
    }
}

interface Car {
    func start():Unit
}

class CarImplem <: Car {
    CarImplem(let engine:Engine, let wheels:Array<Wheel>){}
    public func start() {
        println("vroooom")
        for(w in this.wheels) {
            println(w.id)
        }
    }
}

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

main() {
    let injector = Injector(OptArgs())
    // 泛型参数类型实现了GlobalTypeName接口的类型，可以自动以Wheel.globalTypeName名称注册
    injector.provideValue<Wheel>( Wheel(100))
    // 也可以指定注册名称
    injector.provideValue("wheel-1", Wheel(1))
    injector.provideValue("wheel-2", Wheel(2))
    injector.provideValue("wheel-3", Wheel(3))
    injector.provideValue("wheel-4", Wheel(4))
    // 接口类型的泛型参数只能使用指定名称方式注册
    injector.provide<Car>("Car", {i =>
        // 获取指定名称的实例
        let wheel1 = i.invoke<Wheel>("wheel-1").getOrThrow()
        let wheel2 = i.invoke<Wheel>("wheel-2").getOrThrow()
        let wheel3 = i.invoke<Wheel>("wheel-3").getOrThrow()
        let wheel4 = i.invoke<Wheel>("wheel-4").getOrThrow()
        // 泛型参数类型实现了GlobalTypeName接口的类型，可以获取Wheel.globalTypeName名称的实例
        let wheel5 = i.invoke<Wheel>().getOrThrow()
        let wheel6 = i.invoke<Wheel>().getOrThrow()
        // 接口类型的泛型参数，只能使用指定名称的方式获取
        let engine = i.invoke<Engine>("Engine").getOrThrow()
        var car = CarImplem(engine, [wheel1, wheel2, wheel3, wheel4, wheel5, wheel6])
        return Some(car)
    })
    // 以命名方式注册接口类型的实现
    injector.provide<Engine>("Engine", {i=>
        return Some(EngineImplem())
    })
    // 以指定名称方式获取接口的实现
    let car = injector.invoke<Car>("Car").getOrThrow()
    car.start()

    let state = injector.healthCheck<Engine>("Car")
    println(state)
    let states = injector.healthCheckAll()
    println(states)
}
