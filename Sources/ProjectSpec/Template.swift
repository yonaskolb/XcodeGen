import Foundation
import JSONUtilities

struct TemplateStructure {
    let baseKey: String
    let templatesKey: String
    let nameToReplace: String
}

extension Target {
    static func resolveTargetTemplates(jsonDictionary: JSONDictionary) -> JSONDictionary {
        resolveTemplates(jsonDictionary: jsonDictionary,
                         templateStructure: TemplateStructure(baseKey: "targets",
                                                              templatesKey: "targetTemplates",
                                                              nameToReplace: "target_name"))
    }
}

extension Scheme {
    static func resolveSchemeTemplates(jsonDictionary: JSONDictionary) -> JSONDictionary {
        resolveTemplates(jsonDictionary: jsonDictionary,
                         templateStructure: TemplateStructure(baseKey: "schemes",
                                                              templatesKey: "schemeTemplates",
                                                              nameToReplace: "scheme_name"))
    }
}

private func resolveTemplates(jsonDictionary: JSONDictionary, templateStructure: TemplateStructure) -> JSONDictionary {
    guard var baseDictionary: [String: JSONDictionary] = jsonDictionary[templateStructure.baseKey] as? [String: JSONDictionary] else {
        return jsonDictionary
    }

    let templatesDictionary: [String: JSONDictionary] = jsonDictionary[templateStructure.templatesKey] as? [String: JSONDictionary] ?? [:]

    // Recursively collects all nested template names of a given dictionary.
    func collectTemplates(of jsonDictionary: JSONDictionary,
                          into allTemplates: inout [String],
                          insertAt insertionIndex: inout Int) {
        guard let templates = jsonDictionary["templates"] as? [String] else {
            return
        }
        for template in templates where !allTemplates.contains(template) {
            guard let templateDictionary = templatesDictionary[template] else {
                continue
            }
            allTemplates.insert(template, at: insertionIndex)
            collectTemplates(of: templateDictionary, into: &allTemplates, insertAt: &insertionIndex)
            insertionIndex += 1
        }
    }

    for (referenceName, var reference) in baseDictionary {
        var templates: [String] = []
        var index: Int = 0
        collectTemplates(of: reference, into: &templates, insertAt: &index)
        if !templates.isEmpty {
            var mergedDictionary: JSONDictionary = [:]
            for template in templates {
                if let templateDictionary = templatesDictionary[template] {
                    mergedDictionary = templateDictionary.merged(onto: mergedDictionary)
                }
            }
            reference = reference.merged(onto: mergedDictionary)
            reference = reference.expand(variables: [templateStructure.nameToReplace: referenceName])

            if let templateAttributes = reference["templateAttributes"] as? [String: String] {
                reference = reference.expand(variables: templateAttributes)
            }
        }
        baseDictionary[referenceName] = reference
    }

    var jsonDictionary = jsonDictionary
    jsonDictionary[templateStructure.baseKey] = baseDictionary
    return jsonDictionary
}
