import SwiftUI

@propertyWrapper
struct SecureStorage: DynamicProperty {
    let key: String
    
    @State private var value: String
    
    init(key: String) {
        self.key = key
        
        let data = KeychainHelper.shared.read(service: "com.contexto.keys", account: key)
        if let data = data, let stringValue = String(data: data, encoding: .utf8) {
            self._value = State(initialValue: stringValue)
        } else {
            self._value = State(initialValue: "")
        }
    }
    
    var wrappedValue: String {
        get { value }
        nonmutating set {
            value = newValue
            if let data = newValue.data(using: .utf8) {
                KeychainHelper.shared.save(data, service: "com.contexto.keys", account: key)
            } else {
                KeychainHelper.shared.delete(service: "com.contexto.keys", account: key)
            }
        }
    }
    
    var projectedValue: Binding<String> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
