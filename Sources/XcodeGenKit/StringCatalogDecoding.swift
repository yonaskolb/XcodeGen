import Foundation
import JSONUtilities
import PathKit

struct StringCatalog {
    
/**
*       Sample string catalog:
     
*     {
*        "sourceLanguage" : "en",
*        "strings" : {
*            "foo" : {
*                "localizations" : {
*                    "en" : {
*                        ...
*                    },
*                    "es" : {
*                        ...
*                    },
*                    "it" : {
*                        ...
*                    }
*                }
*            }
*        }
*     }
*/
    
    private struct CatalogItem {
        private enum JSONKeys: String {
            case localizations
        }
        
        private let key: String
        let locales: Set<String>
        
        init?(key: String, from jsonDictionary: JSONDictionary) {
            guard let localizations = jsonDictionary[JSONKeys.localizations.rawValue] as? JSONDictionary else {
                return nil
            }
            
            self.key = key
            self.locales = Set(localizations.keys)
        }
    }
    
    private enum JSONKeys: String {
        case strings
    }
    
    private let strings: [CatalogItem]
    
    init?(from path: Path) {
        guard let catalogDictionary = try? JSONDictionary.from(url: path.url),
              let catalog = StringCatalog(from: catalogDictionary) else {
            return nil
        }
        
        self = catalog
    }
    
    private init?(from jsonDictionary: JSONDictionary) {
        guard let stringsDictionary = jsonDictionary[JSONKeys.strings.rawValue] as? JSONDictionary else {
            return nil
        }

        self.strings = stringsDictionary.compactMap { key, value -> CatalogItem? in
            guard let stringDictionary = value as? JSONDictionary else {
                return nil
            }
            
            return CatalogItem(key: key, from: stringDictionary)
        }
    }
    
    var includedLocales: Set<String> {
        strings.reduce(Set<String>(), { partialResult, catalogItem in
            partialResult.union(catalogItem.locales)
        })
    }
}
