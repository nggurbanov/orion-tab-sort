on run argv
    set journalPath to item 1 of argv
    set sessionKey to "new-native-process"
    set beforeSnapshot to missing value
    set identityObject to current application's NSDictionary's dictionaryWithObjects:{"native-session", "old-native-process"} forKeys:{"mode", "sessionKey"}
    set completedJournal to current application's NSDictionary's dictionaryWithObjects:{"applied", identityObject} forKeys:{"phase", "identity"}
    my putFixtureJournal(completedJournal)
    set resolved to my recoveryJournal(current application's NSDictionary's dictionary())
    if ((resolved's objectForKey:"phase") as text) is not "accepted" then error "Completed previous session remained blocked"
    set archivePath to resolved's objectForKey:"archive"
    set archiveData to current application's NSData's dataWithContentsOfFile:archivePath
    set archiveObject to current application's NSJSONSerialization's JSONObjectWithData:archiveData options:0 |error|:(missing value)
    if ((archiveObject's objectForKey:"phase") as text) is not "applied" then error "Original completed journal was not preserved"
    set repeated to my recoveryJournal(current application's NSDictionary's dictionary())
    if not (((repeated's objectForKey:"archive")'s isEqual:archivePath) as boolean) then error "Completed archive was duplicated"
    repeat with phaseName in {"prepared", "undoing", "rollingBack"}
        set unfinished to current application's NSDictionary's dictionaryWithObjects:{contents of phaseName, identityObject} forKeys:{"phase", "identity"}
        my putFixtureJournal(unfinished)
        set readback to my recoveryJournal(current application's NSDictionary's dictionary())
        if not ((readback's isEqualToDictionary:unfinished) as boolean) then error "Unfinished transaction was automatically retired"
    end repeat
    set sessionKey to "old-native-process"
    my putFixtureJournal(completedJournal)
    set currentJournal to my recoveryJournal(current application's NSDictionary's dictionary())
    if not ((currentJournal's isEqualToDictionary:completedJournal) as boolean) then error "Current-session journal was retired"
    set sessionKey to "new-native-process"
    set beforeSnapshot to current application's NSDictionary's dictionary()
    set retained to my recoveryJournal(current application's NSDictionary's dictionary())
    if not ((retained's isEqualToDictionary:completedJournal) as boolean) then error "Retained Undo journal was retired"
    set beforeSnapshot to missing value
    set legacy to current application's NSDictionary's dictionaryWithObjects:{"applied", current application's NSDictionary's dictionaryWithObject:"saved-UUID" forKey:"windowUUID"} forKeys:{"phase", "identity"}
    my putFixtureJournal(legacy)
    set readback to my recoveryJournal(current application's NSDictionary's dictionary())
    if not ((readback's isEqualToDictionary:legacy) as boolean) then error "Legacy journal was retired without identity verification"
    return "Native journal lifecycle: 8 checks passed. Only private temporary fixtures were written; Orion was not changed."
end run

on putFixtureJournal(valueObject)
    set dataObject to current application's NSJSONSerialization's dataWithJSONObject:valueObject options:2 |error|:(missing value)
    if not ((dataObject's writeToFile:journalPath options:1 |error|:(missing value)) as boolean) then error "Fixture write failed"
end putFixtureJournal
