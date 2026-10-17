property fixtureBefore : missing value
property fixtureApplied : missing value
property fixtureLive : missing value
property failedMoves : {}
property failedWrites : {}
property moveCalls : 0
property writeCalls : 0
property failureCount : 0
property failures : ""
property archiveFailure : false
property resolutionFailure : false
property assertionCount : 0
property snapshotFailure : false

on snapshot()
    if my snapshotFailure then error "Injected snapshot verification failure"
    return my fixtureLive
end snapshot

-- This boundary models partial native moves, not transaction decisions.
on applyLayout(nodes)
    my validateNodes(nodes)
    set my moveCalls to my moveCalls + 1
    set destination to my fixtureApplied
    if (nodes's isEqualToArray:(my movableNodes(my fixtureBefore))) as boolean then set destination to my fixtureBefore
    if my moveCalls is in my failedMoves then
        set my fixtureLive to current application's NSDictionary's dictionaryWithObjects:{"partial", my fixtureBefore's objectForKey:"scope", my fixtureBefore's objectForKey:"tabs"} forKeys:{"revision", "scope", "tabs"}
        error "Injected partial move failure"
    end if
    set my fixtureLive to destination
    return my fixtureLive
end applyLayout

on writeJournal(phaseText, targetObject)
    set my writeCalls to my writeCalls + 1
    if my writeCalls is in my failedWrites then error "Injected journal write failure"
    return my production_writeJournal(phaseText, targetObject)
end writeJournal

on protectedJournalArchive(expectedData, suffixText)
    if my archiveFailure then error "Injected archive I/O failure"
    return my production_protectedJournalArchive(expectedData, suffixText)
end protectedJournalArchive

on saveResolvedJournal(resolved)
    if my resolutionFailure then error "Injected resolution I/O failure"
    return my production_saveResolvedJournal(resolved)
end saveResolvedJournal

on restoreRootExpansion(snapshotObject)
    return true
end restoreRootExpansion

on resetFixture()
    current application's NSFileManager's defaultManager()'s removeItemAtPath:journalPath |error|:(missing value)
    set scopeObject to current application's NSDictionary's dictionaryWithObject:"synthetic" forKey:"groupKey"
    set tabs to current application's NSMutableArray's array()
    set itemMap to current application's NSMutableDictionary's dictionary()
    set metaMap to current application's NSMutableDictionary's dictionary()
    repeat with i from 1 to 2
        set k to "tab-" & i
        set nodeObject to current application's NSDictionary's dictionaryWithObjects:{i, k, current application's NSNull's |null|(), i - 1, false, false, false, "https://example.test/" & i} forKeys:{"id", "key", "parentKey", "index", "expanded", "pinned", "active", "url"}
        tabs's addObject:nodeObject
        itemMap's setObject:k forKey:k
        metaMap's setObject:nodeObject forKey:k
    end repeat
    set changedTabs to current application's NSMutableArray's array()
    repeat with i from 0 to 1
        set n to (tabs's objectAtIndex:i)'s mutableCopy()
        n's setObject:(1 - i) forKey:"index"
        changedTabs's addObject:n
    end repeat
    set my fixtureBefore to current application's NSDictionary's dictionaryWithObjects:{"before", scopeObject, tabs, false} forKeys:{"revision", "scope", "tabs", "rootExpanded"}
    set my fixtureApplied to current application's NSDictionary's dictionaryWithObjects:{"applied", scopeObject, changedTabs, false} forKeys:{"revision", "scope", "tabs", "rootExpanded"}
    set my fixtureLive to my fixtureBefore
    set my contextItems to {"window", "outline", "source", "root", itemMap, metaMap}
    set my beforeSnapshot to missing value
    set my appliedSnapshot to missing value
    set my persistentIdentity to current application's NSDictionary's dictionaryWithObjects:{"before", "native-session", "fixture-process", "scope-uuid"} forKeys:{"revision", "mode", "sessionKey", "windowUUID"}
    set my sessionKey to "fixture-process"
    my clearTransaction()
    set my snapshotFailure to false
    set my archiveFailure to false
    set my resolutionFailure to false
    set my failedMoves to {}
    set my failedWrites to {}
    set my moveCalls to 0
    set my writeCalls to 0
end resetFixture

on applyFixture()
    set p to current application's NSDictionary's dictionaryWithObjects:{my fixtureBefore's objectForKey:"scope", "before", my fixtureApplied's objectForKey:"tabs"} forKeys:{"scope", "expectedRevision", "nodes"}
    return my performCommand("apply", current application's NSDictionary's dictionaryWithObject:p forKey:"plan")
end applyFixture

on expectFailure(commandText)
    set didFail to false
    try
        if commandText is "apply" then
            my applyFixture()
        else
            my performCommand(commandText, current application's NSDictionary's dictionary())
        end if
    on error
        set didFail to true
    end try
    if not didFail then error "Expected command failure: " & commandText
end expectFailure

on checkRestored(expectedObject, labelText)
    if not ((my fixtureLive's isEqualToDictionary:expectedObject) as boolean) then
        set my failureCount to my failureCount + 1
        set my failures to my failures & labelText & "; "
    end if
end checkRestored

on assertTrue(valueObject, labelText)
    if not valueObject then error "Assertion failed: " & labelText
    set my assertionCount to my assertionCount + 1
end assertTrue

on assertLayout(expectedObject)
    my assertTrue((my fixtureLive's isEqualToDictionary:expectedObject) as boolean, "verified destination")
end assertLayout

on assertStatus(phaseText, undoFlag, recoveryFlag, journalText)
    set statusObject to my performCommand("transactionStatus", current application's NSDictionary's dictionary())
    my assertTrue(((statusObject's objectForKey:"transactionPhase") as text) is phaseText, "transaction phase " & phaseText)
    my assertTrue(((statusObject's objectForKey:"canUndo") as boolean) is undoFlag, "canUndo")
    my assertTrue(((statusObject's objectForKey:"needsRecovery") as boolean) is recoveryFlag, "needsRecovery")
    my assertTrue(((statusObject's objectForKey:"journalPhase") as text) is journalText, "durable phase " & journalText)
end assertStatus

on resumeRetained(targetName)
    set payload to current application's NSDictionary's dictionaryWithObjects:{my fixtureLive's objectForKey:"revision", targetName} forKeys:{"expectedRevision", "target"}
    my performCommand("recoverRetained", payload)
end resumeRetained

on previousJournal(phaseText)
    my resetFixture()
    set identityObject to current application's NSDictionary's dictionaryWithObjects:{"native-session", "previous-process", "unrelated-old-scope"} forKeys:{"mode", "sessionKey", "windowUUID"}
    set journalObject to current application's NSDictionary's dictionaryWithObjects:{1, phaseText, identityObject, my fixtureBefore} forKeys:{"version", "phase", "identity", "before"}
    set dataObject to current application's NSJSONSerialization's dataWithJSONObject:journalObject options:2 |error|:(missing value)
    dataObject's writeToFile:journalPath options:1 |error|:(missing value)
    set inspection to my performCommand("inspectJournal", current application's NSDictionary's dictionary())
    return current application's NSMutableDictionary's dictionaryWithObjects:{true, inspection's objectForKey:"journalRevision", 1, identityObject, "before"} forKeys:{"confirmed", "expectedJournalRevision", "expectedJournalVersion", "expectedJournalIdentity", "expectedRevision"}
end previousJournal

on expectPayloadFailure(commandText, payload)
    set didFail to false
    try
        my performCommand(commandText, payload)
    on error
        set didFail to true
    end try
    my assertTrue(didFail, "reject unsafe " & commandText)
end expectPayloadFailure

on prepareVerifiedRecovery()
    my resetFixture()
    set my fixtureLive to my fixtureApplied
    set bindings to current application's NSMutableArray's array()
    repeat with i from 1 to 2
        bindings's addObject:(current application's NSDictionary's dictionaryWithObjects:{"tab-" & i, "uuid-" & i} forKeys:{"key", "uuid"})
    end repeat
    set my persistentIdentity to current application's NSDictionary's dictionaryWithObjects:{"applied", "native-session", "fixture-process", "scope-uuid", bindings} forKeys:{"revision", "mode", "sessionKey", "windowUUID", "tabs"}
    set journalObject to current application's NSDictionary's dictionaryWithObjects:{1, "prepared", my persistentIdentity, my fixtureBefore} forKeys:{"version", "phase", "identity", "before"}
    my production_saveResolvedJournal(journalObject)
    set planObject to current application's NSDictionary's dictionaryWithObjects:{my fixtureBefore's objectForKey:"scope", "applied", my fixtureBefore's objectForKey:"tabs"} forKeys:{"scope", "expectedRevision", "nodes"}
    return current application's NSDictionary's dictionaryWithObject:planObject forKey:"plan"
end prepareVerifiedRecovery

on run argv
    set journalPath to item 1 of argv
    my resetFixture()
    my applyFixture()
    set my failedMoves to {2}
    my expectFailure("undo")
    my checkRestored(my fixtureApplied, "Undo partial failure is not compensated")
    my resetFixture()
    set my failedMoves to {1}
    set my failedWrites to {2}
    my expectFailure("apply")
    my checkRestored(my fixtureBefore, "Apply rollback skipped after journal I/O error")
    if my failureCount is not 0 then error my failures

    -- Success, repetition and reuse, with real journal serialization.
    my resetFixture()
    my applyFixture()
    my assertLayout(my fixtureApplied)
    my assertStatus("applied", true, false, "applied")
    my expectFailure("apply")
    my performCommand("undo", current application's NSDictionary's dictionary())
    my assertLayout(my fixtureBefore)
    my assertStatus("idle", false, false, "undone")
    my expectFailure("undo")
    my expectFailure("keep")
    my applyFixture()
    my assertStatus("applied", true, false, "applied")
    my performCommand("keep", current application's NSDictionary's dictionary())
    my assertStatus("idle", false, false, "accepted")
    my expectFailure("keep")

    -- Apply write-ahead, finalization, rollback-start and rollback-final writes.
    my resetFixture()
    set my failedWrites to {1}
    my expectFailure("apply")
    my assertTrue(my moveCalls is 0, "write-ahead before moves")
    my assertStatus("idle", false, false, "none")
    my resetFixture()
    set my failedWrites to {2}
    my expectFailure("apply")
    my assertLayout(my fixtureBefore)
    my assertStatus("idle", false, false, "rolledBack")
    my resetFixture()
    set my failedMoves to {1}
    set my failedWrites to {2}
    my expectFailure("apply")
    my assertLayout(my fixtureBefore)
    my assertTrue(my moveCalls is 2, "journal failure did not skip compensation")
    my assertStatus("idle", false, false, "rolledBack")
    repeat with failedBoundary in {{3}, {2, 3}}
        my resetFixture()
        set my failedMoves to {1}
        set my failedWrites to contents of failedBoundary
        my expectFailure("apply")
        my assertLayout(my fixtureBefore)
        if contents of failedBoundary is {3} then
            my assertStatus("restoredJournalPending", false, true, "rollingBack")
        else
            my assertStatus("restoredJournalPending", false, true, "prepared")
        end if
        my expectFailure("keep")
        my expectFailure("undo")
        my expectFailure("apply")
        my resumeRetained("original")
        my assertStatus("idle", false, false, "rolledBack")
    end repeat

    -- Undo write-ahead, finalization, compensation-start and compensation-final writes.
    my resetFixture()
    my applyFixture()
    set my failedWrites to {3}
    my expectFailure("undo")
    my assertTrue(my moveCalls is 1, "Undo write-ahead before moves")
    my assertStatus("applied", true, false, "applied")
    my resetFixture()
    my applyFixture()
    set my failedWrites to {4}
    my expectFailure("undo")
    my assertLayout(my fixtureApplied)
    my assertStatus("applied", true, false, "applied")
    my resetFixture()
    my applyFixture()
    set my failedMoves to {2}
    set my failedWrites to {4}
    my expectFailure("undo")
    my assertLayout(my fixtureApplied)
    my assertStatus("applied", true, false, "applied")
    my resetFixture()
    my applyFixture()
    set my failedMoves to {2}
    set my failedWrites to {5}
    my expectFailure("undo")
    my assertLayout(my fixtureApplied)
    my assertStatus("appliedJournalPending", false, true, "rollingBack")
    my expectFailure("keep")
    my expectFailure("undo")
    my resumeRetained("applied")
    my assertStatus("applied", true, false, "applied")

    -- Failed compensation retains both original and partial evidence.
    repeat with originCommand in {"apply", "undo"}
        my resetFixture()
        if contents of originCommand is "apply" then
            set my failedMoves to {1, 2}
        else
            my applyFixture()
            set my failedMoves to {2, 3}
        end if
        my expectFailure(contents of originCommand)
        my assertStatus("recoveryRequired", false, true, "recoveryRequired")
        my assertTrue(my beforeSnapshot is not missing value, "original snapshot retained")
        my assertTrue(my partialSnapshot is not missing value, "partial evidence retained")
        set evidence to (my inspectJournal(current application's NSDictionary's dictionary()))'s objectForKey:"journal"
        my assertTrue((evidence's objectForKey:"partial") is not missing value, "partial evidence durable")
        my expectFailure("keep")
        my expectFailure("undo")
        my expectFailure("apply")
        my expectPayloadFailure("recoverRetained", current application's NSDictionary's dictionaryWithObjects:{"stale", "original"} forKeys:{"expectedRevision", "target"})
        my resumeRetained("original")
        my assertLayout(my fixtureBefore)
        my assertStatus("idle", false, false, "rolledBack")
    end repeat
    my resetFixture()
    set my failedMoves to {1, 2}
    set my failedWrites to {3}
    my expectFailure("apply")
    my assertStatus("recoveryRequired", false, true, "rollingBack")
    my resumeRetained("original")
    my assertStatus("idle", false, false, "rolledBack")

    -- Failed snapshot verification is evidence of uncertainty, never success.
    my resetFixture()
    my applyFixture()
    set my snapshotFailure to true
    set my failedMoves to {2}
    set outcome to my compensateLayout(my fixtureBefore, "rolledBack")
    my assertTrue(my transactionPhase is "recoveryRequired", "unverified compensation retained")
    my assertTrue((my partialSnapshot's objectForKey:"snapshotError") is not missing value, "failed snapshot evidence retained")
    my assertStatus("recoveryRequired", false, true, "recoveryRequired")
    set my snapshotFailure to false
    my resumeRetained("original")
    my assertStatus("idle", false, false, "rolledBack")

    -- Divergent live layout and journal mismatch cannot be kept or undone.
    my resetFixture()
    my applyFixture()
    set my fixtureLive to my fixtureBefore
    my expectFailure("keep")
    my expectFailure("undo")
    my assertTrue(my beforeSnapshot is not missing value, "divergence retained Undo evidence")
    my assertTrue(my moveCalls is 1, "divergence made no moves")
    my assertStatus("applied", false, true, "applied")
    set my fixtureLive to my fixtureApplied
    set journalObject to (my inspectJournal(current application's NSDictionary's dictionary()))'s objectForKey:"journal"
    set altered to journalObject's mutableCopy()
    altered's setObject:"wrong-transaction" forKey:"transactionID"
    my production_saveResolvedJournal(altered)
    my expectFailure("keep")
    my expectFailure("undo")
    my assertStatus("applied", false, true, "applied")

    -- Archive or resolution failure cannot clear retained verified state.
    repeat with failingStage in {"archive", "resolution"}
        my resetFixture()
        my applyFixture()
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        if contents of failingStage is "archive" then
            set my archiveFailure to true
        else
            set my resolutionFailure to true
        end if
        my expectFailure("keep")
        my assertStatus("applied", true, false, "applied")
        set my archiveFailure to false
        set my resolutionFailure to false
        my performCommand("keep", current application's NSDictionary's dictionary())
        set resolved to (my inspectJournal(current application's NSDictionary's dictionary()))'s objectForKey:"journal"
        set archivePath to resolved's objectForKey:"archive"
        set archiveData to current application's NSData's dataWithContentsOfFile:archivePath
        my assertTrue((originalData's isEqualToData:archiveData) as boolean, "byte-exact archive")
        set attributes to current application's NSFileManager's defaultManager()'s attributesOfItemAtPath:archivePath |error|:(missing value)
        my assertTrue(((attributes's objectForKey:(current application's NSFilePosixPermissions)) as integer) is 384, "protected 0600 archive")
    end repeat

    -- Prior-session acknowledgment is explicit and never maps old IDs to live tabs.
    repeat with phaseName in {"prepared", "undoing", "rollingBack", "recoveryRequired"}
        set payload to my previousJournal(contents of phaseName)
        my assertStatus("idle", false, true, contents of phaseName)
        set originalData to current application's NSData's dataWithContentsOfFile:journalPath
        set resolved to my performCommand("acknowledgeCurrent", payload)
        my assertTrue(((resolved's objectForKey:"phase") as text) is "acknowledged", "acknowledgment phase")
        my assertTrue((resolved's objectForKey:"recovered") is missing value, "not falsely restored")
        my assertTrue(my moveCalls is 0, "acknowledgment made no moves")
        set archiveData to current application's NSData's dataWithContentsOfFile:(resolved's objectForKey:"archive")
        my assertTrue((originalData's isEqualToData:archiveData) as boolean, "prior journal preserved")
        my assertStatus("idle", false, false, "acknowledged")
        my expectPayloadFailure("acknowledgeCurrent", payload)
    end repeat
    repeat with fieldName in {"confirmed", "expectedJournalRevision", "expectedJournalVersion", "expectedJournalIdentity", "expectedRevision"}
        set payload to my previousJournal("prepared")
        payload's removeObjectForKey:(contents of fieldName)
        my expectPayloadFailure("acknowledgeCurrent", payload)
        my assertStatus("idle", false, true, "prepared")
    end repeat
    repeat with fieldName in {"confirmed", "expectedJournalRevision", "expectedJournalVersion", "expectedJournalIdentity", "expectedRevision"}
        set payload to my previousJournal("undoing")
        payload's setObject:"wrong" forKey:(contents of fieldName)
        my expectPayloadFailure("acknowledgeCurrent", payload)
        my assertTrue(my moveCalls is 0, "stale acknowledgment made no moves")
    end repeat
    repeat with failingStage in {"archive", "resolution"}
        set payload to my previousJournal("rollingBack")
        if contents of failingStage is "archive" then
            set my archiveFailure to true
        else
            set my resolutionFailure to true
        end if
        my expectPayloadFailure("acknowledgeCurrent", payload)
        my assertStatus("idle", false, true, "rollingBack")
        set my archiveFailure to false
        set my resolutionFailure to false
        my performCommand("acknowledgeCurrent", payload)
        my assertStatus("idle", false, false, "acknowledged")
    end repeat
    set payload to my previousJournal("prepared")
    set my sessionKey to "previous-process"
    my expectPayloadFailure("acknowledgeCurrent", payload)
    set payload to my previousJournal("prepared")
    set my beforeSnapshot to my fixtureBefore
    my expectPayloadFailure("acknowledgeCurrent", payload)
    set payload to my previousJournal("prepared")
    my expectPayloadFailure("recover", current application's NSDictionary's dictionary())
    my assertTrue(my moveCalls is 0, "cross-session recovery forbidden")
    -- Execute the existing UUID-verified recovery path with the same transaction machinery.
    set payload to my prepareVerifiedRecovery()
    my performCommand("recover", payload)
    my assertLayout(my fixtureBefore)
    my assertStatus("idle", false, false, "recovered")
    repeat with boundaryIndex in {1, 2}
        set payload to my prepareVerifiedRecovery()
        set my failedWrites to {contents of boundaryIndex}
        my expectPayloadFailure("recover", payload)
        my assertLayout(my fixtureApplied)
        if contents of boundaryIndex is 1 then
            my assertTrue(my moveCalls is 0, "recovery write-ahead before moves")
            my assertStatus("idle", false, true, "prepared")
        else
            my assertStatus("idle", false, false, "rolledBack")
        end if
    end repeat
    set payload to my prepareVerifiedRecovery()
    set my failedMoves to {1, 2}
    my expectPayloadFailure("recover", payload)
    my assertStatus("recoveryRequired", false, true, "recoveryRequired")
    my assertTrue(my recoveryArchive is not missing value, "original recovery archive retained")
    my resumeRetained("original")
    my assertLayout(my fixtureApplied)
    my assertStatus("idle", false, false, "rolledBack")

    -- Invalid disk evidence must still produce safe reply flags.
    repeat with invalidText in {"not JSON", "[]", "{}", "{\"phase\":\"future-unknown\"}"}
        my resetFixture()
        set textData to (current application's NSString's stringWithString:(contents of invalidText))'s dataUsingEncoding:4
        textData's writeToFile:journalPath options:1 |error|:(missing value)
        set statusObject to my transactionStatus()
        my assertTrue(not ((statusObject's objectForKey:"canUndo") as boolean), "invalid journal cannot Undo")
        my assertTrue((statusObject's objectForKey:"needsRecovery") as boolean, "invalid journal blocks Apply")
        my expectFailure("apply")
        my assertTrue(my moveCalls is 0, "invalid journal made no moves")
    end repeat

    -- The installer executes these exact guards before reusing any host object.
    my validateLoadedRevision("OrionNativeTreeHostV3R49")
    set refused to false
    try
        my validateLoadedRevision("OrionNativeTreeHostV3R48")
    on error
        set refused to true
    end try
    my assertTrue(refused, "mixed loaded revision refused")
    set runtimeObject to current application's NSDictionary's dictionaryWithObjects:{"chrome-extension://@@EXTENSION_ID@@/sorter.html", "@@RUNTIME_ROOT@@/state/native-session-undo.json"} forKeys:{"controllerURL", "journalPath"}
    my validateRuntime(runtimeObject)
    set refused to false
    try
        my validateRuntime(current application's NSDictionary's dictionaryWithObjects:{"chrome-extension://different/sorter.html", "@@RUNTIME_ROOT@@/state/native-session-undo.json"} forKeys:{"controllerURL", "journalPath"})
    on error
        set refused to true
    end try
    my assertTrue(refused, "mixed runtime configuration refused")
    return "Shipped transaction handlers: " & my assertionCount & " assertions passed (success, partial moves, all journal boundaries, retained recovery, Keep divergence, protected archive and explicit prior-session acknowledgment). No Orion was loaded or changed."
end run
