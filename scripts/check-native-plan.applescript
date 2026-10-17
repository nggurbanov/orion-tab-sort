-- Foundation-only guard tests. No Orion, NSApplication, or UI calls.
use framework "Foundation"

on decodeJSON(jsonText)
    set jsonData to (current application's NSString's stringWithString:jsonText)'s dataUsingEncoding:4
    return current application's NSJSONSerialization's JSONObjectWithData:jsonData options:0 |error|:(missing value)
end decodeJSON

set itemMap to current application's NSMutableDictionary's dictionary()
itemMap's setObject:(current application's NSObject's alloc()'s init()) forKey:"1"
itemMap's setObject:(current application's NSObject's alloc()'s init()) forKey:"2"
set metaMap to my decodeJSON("{\"1\":{\"id\":1},\"2\":{\"id\":2}}")
set my contextItems to {missing value, missing value, missing value, missing value, itemMap, metaMap}
set validNodes to my decodeJSON("[{\"id\":1,\"key\":\"1\",\"parentKey\":null,\"index\":0,\"expanded\":true},{\"id\":2,\"key\":\"2\",\"parentKey\":\"1\",\"index\":0,\"expanded\":false}]")
set resultMap to my validateNodes(validNodes)
if (resultMap's |count|() as integer) is not 2 then error "Valid tree rejected"
set invalidCases to {¬
    "[{\"id\":1,\"key\":\"1\",\"parentKey\":null,\"index\":0,\"expanded\":true}]", ¬
    "[{\"id\":1,\"key\":\"1\",\"parentKey\":\"2\",\"index\":0,\"expanded\":true},{\"id\":2,\"key\":\"2\",\"parentKey\":\"1\",\"index\":0,\"expanded\":false}]", ¬
    "[{\"id\":1,\"key\":\"1\",\"parentKey\":null,\"index\":0,\"expanded\":true},{\"id\":2,\"key\":\"2\",\"parentKey\":null,\"index\":0,\"expanded\":false}]", ¬
    "[{\"id\":1,\"key\":\"1\",\"parentKey\":null,\"index\":0,\"expanded\":true},{\"id\":2,\"key\":\"2\",\"parentKey\":null,\"index\":2,\"expanded\":false}]", ¬
    "[{\"id\":1,\"key\":\"1\",\"parentKey\":null,\"index\":0,\"expanded\":true},{\"id\":2,\"key\":\"2\",\"parentKey\":\"999\",\"index\":0,\"expanded\":false}]", ¬
    "[{\"id\":1,\"key\":\"1\",\"parentKey\":null,\"index\":0,\"expanded\":true},{\"id\":99,\"key\":\"2\",\"parentKey\":\"1\",\"index\":0,\"expanded\":false}]", ¬
    "[{\"id\":1,\"key\":\"1\",\"parentKey\":null,\"index\":0,\"expanded\":true},{\"id\":2,\"key\":\"2\",\"parentKey\":\"1\",\"index\":0,\"expanded\":\"false\"}]"}
set rejectedCount to 0
repeat with invalidJSON in invalidCases
    set wasRejected to false
    try
        my validateNodes(my decodeJSON(invalidJSON as text))
    on error
        set wasRejected to true
    end try
    if not wasRejected then error "Invalid plan accepted"
    set rejectedCount to rejectedCount + 1
end repeat
return "Foundation-only native plan guards: valid tree accepted; " & rejectedCount & " invalid trees rejected. No native tree operations ran."
