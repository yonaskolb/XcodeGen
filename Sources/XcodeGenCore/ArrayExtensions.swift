import Foundation

public extension Array {

   func parallelMap<T>(transform: (Element) -> T) -> [T] {
       var result = ContiguousArray<T?>(repeating: nil, count: count)
       return result.withUnsafeMutableBufferPointer { buffer in
           DispatchQueue.concurrentPerform(iterations: buffer.count) { idx in
               buffer[idx] = transform(self[idx])
           }
           return buffer.map { $0! }
       }
   }
}
