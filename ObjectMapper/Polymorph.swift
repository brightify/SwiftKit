//
//  Polymorph.swift
//  Pods
//
//  Created by Tadeáš Kříž on 6/29/15.
//
//

import Foundation

class Polymorph {
    
    private var cacheMap: [ObjectIdentifier: PolymorphCache] = [:]
    
    func getCache(annotationType: PolymorphicMappable.Type) -> PolymorphCache? {
        let identifier = ObjectIdentifier(annotationType)
        
        return cacheMap[identifier]
    }
    
    func wipeCache(annotationType: PolymorphicMappable.Type) {
        let identifier = ObjectIdentifier(annotationType)
        
        cacheMap.removeValueForKey(identifier)
    }
    
    func isCached(annotationType: PolymorphicMappable.Type) -> Bool {
        return getCache(annotationType) != nil
    }
    
    func cache(annotatedType: PolymorphicMappable.Type, force: Bool = false) -> PolymorphCache {
        if let oldCache = getCache(annotatedType) {
            if (force) {
                wipeCache(annotatedType)
            } else {
                return oldCache
            }
        }
        
        let cache = PolymorphCache()
        
        let registeredTypes = Polymorph.collectAllRegisteredTypes(annotatedType)
        
        for type in registeredTypes {
            switch (type.use) {
            case .Class(let property, let className):
                cache.register(property, propertyValue: className, type: type.type)
            case .Name(let property, let value):
                cache.register(property, propertyValue: value, type: type.type)
            }
        }
        
        let identifier = ObjectIdentifier(annotatedType)
        cacheMap[identifier] = cache
        return cache
    }
    
    func concreteTypeFor<M: Mappable>(type: M.Type, inMap map: Map) -> M.Type {
        if let annotatedType = type as? PolymorphicMappable.Type {
            let cache = self.cache(annotatedType)
            
            for (propertyName, valueToType) in cache.deserializationMap {
                if let value: String = map[propertyName].value(), type = valueToType[value] as? M.Type {
                    return type
                }
            }
        }
        
        return type
    }
    
    func writeTypeInfoToMap<M: Mappable>(map: Map, ofType type: M.Type, forObject object: M) {
        if let annotatedType = type as? PolymorphicMappable.Type {
            let identifier = ObjectIdentifier(object.dynamicType)
            let cache = self.cache(annotatedType)
            
            if let property = cache.serializationMap[identifier] {
                map[property.name].setValue(NSString(string: property.value))
            }
        }
        
    }
    
    private class func extractTypeInfo(type: PolymorphicMappable.Type) -> JsonTypeInfo? {
        // We cast the type to `AnyClass` so we can dynamically invoke the static method.
        // TODO When Swift' protocol class level access is implemented we should switch to it
        return type.jsonTypeInfo()
    }
    
    private class func collectAllRegisteredTypes(type: PolymorphicMappable.Type) -> [PolymorphicType] {
        return extractTypeInfo(type)?.registeredTypes.flatMap(collectChildRegisteredTypes(type)) ?? []
    }
    
    private class func collectChildRegisteredTypes(parentBaseType: PolymorphicMappable.Type) -> PolymorphicType -> [PolymorphicType] {
        return { type in
            var output = [type]
            
            if let typeInfo = self.extractTypeInfo(type.type) {
                if(ObjectIdentifier(typeInfo.baseType) != ObjectIdentifier(parentBaseType)) {
                    output += typeInfo.registeredTypes.flatMap(self.collectChildRegisteredTypes(typeInfo.baseType))
                }
            }
            
            return output
        }
    }
}