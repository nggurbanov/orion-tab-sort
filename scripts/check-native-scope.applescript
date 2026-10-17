-- Foundation objects only. The exact production handler is exercised.
script ScopeTestWindow
    property testWindowNumber : 10570
    on windowNumber()
        return my testWindowNumber
    end windowNumber
end script
set a to current application's NSObject's alloc()'s init()
set b to current application's NSObject's alloc()'s init()
set c to current application's NSObject's alloc()'s init()
set baseline to {{a, missing value, 0}, {b, a, 0}}
set token1 to my nativeScopeSignature(ScopeTestWindow, baseline)
if (my nativeScopeSignature(ScopeTestWindow, {{b, missing value, 0}, {a, b, 0}}) as text) is not (token1 as text) then error "Reordering changed scope membership token"
set token2 to my nativeScopeSignature(ScopeTestWindow, {{a, missing value, 0}, {c, a, 0}})
if (token2 as text) is (token1 as text) then error "Different in-place group retained old scope token"
if (my nativeScopeSignature(ScopeTestWindow, baseline) as text) is not (token1 as text) then error "Returning group lost its session token"
set ScopeTestWindow's testWindowNumber to 11208
if (my nativeScopeSignature(ScopeTestWindow, baseline) as text) is (token1 as text) then error "Other physical window shared scope token"
set fragmentText to my jsonText(current application's NSString's stringWithString:"model-\"quoted\"")
if (fragmentText as text) is not "\"model-\\\"quoted\\\"\"" then error "JSON string fragment was not escaped"
return "Native scope identity: 5 Foundation checks passed. No Orion or UI calls."
