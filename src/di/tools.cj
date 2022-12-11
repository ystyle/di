package di

public interface GlobalTypeName {
   static func getGlobalTypeName():String
}
public interface NewInstance<T> {
    static func new():T
}