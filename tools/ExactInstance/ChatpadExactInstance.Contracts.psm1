Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:PlanSchema = 'chatpad-exact-instance-operation-plan-v1'
$script:SnapshotSchema = 'chatpad-exact-instance-restoration-snapshot-v1'
$script:EvidenceSchema = 'chatpad-exact-instance-operation-evidence-v1'
$script:PendingAuditBlocker = 'BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT'
$script:LiveAdapterBlocker = 'BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED'
$script:CanonicalJsonVersion = 'chatpad-canonical-json-v1'
$script:AllowedModes = @('Plan','Apply','Restore','Verify')
$script:AllowedActions = @('query-exact-device','verify-package','bind-exact-device','verify-exact-device','restore-exact-device','restart-exact-device')
$script:AllowedTransitions = [ordered]@{
    PLAN_CREATED=@('PLAN_VALIDATED','BLOCKED')
    PLAN_VALIDATED=@('PREFLIGHT_STARTED','BLOCKED')
    PREFLIGHT_STARTED=@('TARGET_OPENED','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    TARGET_OPENED=@('TARGET_IDENTITY_VERIFIED','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    TARGET_IDENTITY_VERIFIED=@('SNAPSHOT_CAPTURED','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    SNAPSHOT_CAPTURED=@('PACKAGE_IDENTITY_VERIFIED','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    PACKAGE_IDENTITY_VERIFIED=@('READY_TO_BIND','BIND_FAILED_BEFORE_MUTATION','BLOCKED')
    READY_TO_BIND=@('BIND_STARTED','BLOCKED')
    BIND_STARTED=@('BIND_API_SUCCEEDED','BIND_FAILED_AFTER_MUTATION','RESTORE_REQUIRED')
    BIND_API_SUCCEEDED=@('POST_BIND_VERIFY_STARTED','RESTORE_REQUIRED')
    POST_BIND_VERIFY_STARTED=@('BIND_VERIFIED','RESTORE_REQUIRED')
    BIND_VERIFIED=@('RESTART_REQUIRED','REBOOT_REQUIRED','COMPLETED','RESTORE_STARTED')
    RESTART_REQUIRED=@('COMPLETED','RESTORE_STARTED','BLOCKED')
    REBOOT_REQUIRED=@('BLOCKED','RESTORE_STARTED')
    BIND_FAILED_BEFORE_MUTATION=@('BLOCKED')
    BIND_FAILED_AFTER_MUTATION=@('RESTORE_REQUIRED','BLOCKED')
    RESTORE_REQUIRED=@('RESTORE_STARTED','BLOCKED')
    RESTORE_STARTED=@('RESTORE_API_SUCCEEDED','RESTORE_FAILED')
    RESTORE_API_SUCCEEDED=@('POST_RESTORE_VERIFY_STARTED','RESTORE_FAILED')
    POST_RESTORE_VERIFY_STARTED=@('RESTORED','RESTORE_FAILED')
    RESTORED=@('COMPLETED')
    RESTORE_FAILED=@('BLOCKED')
    BLOCKED=@()
    COMPLETED=@()
}

if ($null -eq ('ChatpadExactJsonParser' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

public static class ChatpadExactJsonParser
{
    private sealed class Parser
    {
        private readonly string text;
        private int index;

        internal Parser(string value)
        {
            if (value == null) throw new ArgumentNullException("value");
            text = value;
        }

        internal object Parse()
        {
            SkipWhitespace();
            object value = ParseValue("$");
            SkipWhitespace();
            if (index != text.Length) Error("JSON_TRAILING_CONTENT", "$");
            return value;
        }

        private object ParseValue(string path)
        {
            SkipWhitespace();
            if (index >= text.Length) Error("JSON_UNEXPECTED_END", path);
            char c = text[index];
            if (c == '{') return ParseObject(path);
            if (c == '[') return ParseArray(path);
            if (c == '"') return ParseString(path);
            if (c == 't') { ReadLiteral("true", path); return true; }
            if (c == 'f') { ReadLiteral("false", path); return false; }
            if (c == 'n') { ReadLiteral("null", path); return null; }
            if (c == '-' || (c >= '0' && c <= '9')) return ParseNumber(path);
            Error("JSON_TOKEN_INVALID", path);
            return null;
        }

        private object ParseObject(string path)
        {
            index++;
            Dictionary<string, object> result = new Dictionary<string, object>(StringComparer.Ordinal);
            HashSet<string> names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            SkipWhitespace();
            if (Take('}')) return result;
            while (true)
            {
                SkipWhitespace();
                if (index >= text.Length || text[index] != '"') Error("JSON_PROPERTY_NAME_INVALID", path);
                string name = ParseString(path);
                string childPath = SafePath(path, name);
                if (!names.Add(name))
                    throw new FormatException("DUPLICATE_JSON_PROPERTY|path=" + childPath + "|property=" + SafeName(name));
                SkipWhitespace();
                if (!Take(':')) Error("JSON_PROPERTY_SEPARATOR_MISSING", childPath);
                result.Add(name, ParseValue(childPath));
                SkipWhitespace();
                if (Take('}')) return result;
                if (!Take(',')) Error("JSON_OBJECT_SEPARATOR_MISSING", path);
            }
        }

        private object ParseArray(string path)
        {
            index++;
            List<object> result = new List<object>();
            SkipWhitespace();
            if (Take(']')) return result;
            while (true)
            {
                result.Add(ParseValue(path + "[" + result.Count.ToString(CultureInfo.InvariantCulture) + "]"));
                SkipWhitespace();
                if (Take(']')) return result;
                if (!Take(',')) Error("JSON_ARRAY_SEPARATOR_MISSING", path);
            }
        }

        private string ParseString(string path)
        {
            if (!Take('"')) Error("JSON_STRING_INVALID", path);
            StringBuilder result = new StringBuilder();
            while (index < text.Length)
            {
                char c = text[index++];
                if (c == '"') return result.ToString();
                if (c < 0x20) Error("JSON_STRING_CONTROL_INVALID", path);
                if (c != '\\')
                {
                    if (char.IsHighSurrogate(c))
                    {
                        if (index >= text.Length || !char.IsLowSurrogate(text[index]))
                            Error("JSON_STRING_SURROGATE_INVALID", path);
                        result.Append(c);
                        result.Append(text[index++]);
                    }
                    else
                    {
                        if (char.IsLowSurrogate(c)) Error("JSON_STRING_SURROGATE_INVALID", path);
                        result.Append(c);
                    }
                    continue;
                }
                if (index >= text.Length) Error("JSON_STRING_ESCAPE_INVALID", path);
                char escape = text[index++];
                switch (escape)
                {
                    case '"': result.Append('"'); break;
                    case '\\': result.Append('\\'); break;
                    case '/': result.Append('/'); break;
                    case 'b': result.Append('\b'); break;
                    case 'f': result.Append('\f'); break;
                    case 'n': result.Append('\n'); break;
                    case 'r': result.Append('\r'); break;
                    case 't': result.Append('\t'); break;
                    case 'u': result.Append(ParseUnicode(path)); break;
                    default: Error("JSON_STRING_ESCAPE_INVALID", path); break;
                }
            }
            Error("JSON_UNEXPECTED_END", path);
            return null;
        }

        private string ParseUnicode(string path)
        {
            int first = ParseHex4(path);
            char high = (char)first;
            if (char.IsLowSurrogate(high)) Error("JSON_STRING_SURROGATE_INVALID", path);
            if (!char.IsHighSurrogate(high)) return high.ToString();
            if (index + 6 > text.Length || text[index] != '\\' || text[index + 1] != 'u')
                Error("JSON_STRING_SURROGATE_INVALID", path);
            index += 2;
            char low = (char)ParseHex4(path);
            if (!char.IsLowSurrogate(low)) Error("JSON_STRING_SURROGATE_INVALID", path);
            return new string(new char[] { high, low });
        }

        private int ParseHex4(string path)
        {
            if (index + 4 > text.Length) Error("JSON_STRING_ESCAPE_INVALID", path);
            int value = 0;
            for (int i = 0; i < 4; i++)
            {
                char c = text[index++];
                int digit = c >= '0' && c <= '9' ? c - '0' :
                    c >= 'a' && c <= 'f' ? c - 'a' + 10 :
                    c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
                if (digit < 0) Error("JSON_STRING_ESCAPE_INVALID", path);
                value = value * 16 + digit;
            }
            return value;
        }

        private object ParseNumber(string path)
        {
            int start = index;
            Take('-');
            if (index >= text.Length) Error("JSON_NUMBER_INVALID", path);
            if (text[index] == '0')
            {
                index++;
                if (index < text.Length && char.IsDigit(text[index])) Error("JSON_NUMBER_LEADING_ZERO", path);
            }
            else
            {
                if (text[index] < '1' || text[index] > '9') Error("JSON_NUMBER_INVALID", path);
                while (index < text.Length && char.IsDigit(text[index])) index++;
            }
            if (Take('.'))
            {
                int fraction = index;
                while (index < text.Length && char.IsDigit(text[index])) index++;
                if (fraction == index) Error("JSON_NUMBER_INVALID", path);
            }
            if (index < text.Length && (text[index] == 'e' || text[index] == 'E'))
            {
                index++;
                if (index < text.Length && (text[index] == '+' || text[index] == '-')) index++;
                int exponent = index;
                while (index < text.Length && char.IsDigit(text[index])) index++;
                if (exponent == index) Error("JSON_NUMBER_INVALID", path);
            }
            string token = text.Substring(start, index - start);
            long integer;
            if (token.IndexOf('.') < 0 && token.IndexOf('e') < 0 && token.IndexOf('E') < 0 &&
                Int64.TryParse(token, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out integer))
                return integer;
            decimal number;
            if (!Decimal.TryParse(token, NumberStyles.Float, CultureInfo.InvariantCulture, out number))
                Error("JSON_NUMBER_UNSUPPORTED", path);
            return number;
        }

        private void ReadLiteral(string literal, string path)
        {
            if (index + literal.Length > text.Length ||
                String.CompareOrdinal(text, index, literal, 0, literal.Length) != 0)
                Error("JSON_LITERAL_INVALID", path);
            index += literal.Length;
        }

        private bool Take(char expected)
        {
            if (index < text.Length && text[index] == expected) { index++; return true; }
            return false;
        }

        private void SkipWhitespace()
        {
            while (index < text.Length &&
                (text[index] == ' ' || text[index] == '\t' || text[index] == '\r' || text[index] == '\n'))
                index++;
        }

        private static string SafePath(string path, string name)
        {
            return path + "." + SafeName(name);
        }

        private static string SafeName(string name)
        {
            StringBuilder safe = new StringBuilder();
            foreach (char c in name)
                safe.Append((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                    (c >= '0' && c <= '9') || c == '_' || c == '-' ? c : '_');
            return safe.Length == 0 ? "_" : safe.ToString();
        }

        private static void Error(string code, string path)
        {
            throw new FormatException(code + "|path=" + path);
        }
    }

    public static object Parse(string json)
    {
        return new Parser(json).Parse();
    }
}
'@
}

function Copy-ChatpadExactObject {
    param([Parameter(Mandatory)][object]$InputObject)
    [Management.Automation.PSSerializer]::Deserialize([Management.Automation.PSSerializer]::Serialize($InputObject,40))
}

function Get-ChatpadExactSha256Text {
    param([Parameter(Mandatory)][string]$Text)
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        ($sha.ComputeHash($bytes)|ForEach-Object{$_.ToString('x2')}) -join ''
    } finally {
        $sha.Dispose()
    }
}

function ConvertFrom-ChatpadExactJson {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Json)
    try {
        [ChatpadExactJsonParser]::Parse($Json)
    } catch {
        throw [FormatException]::new($_.Exception.Message,$_.Exception)
    }
}

function Test-ChatpadExactJsonDocument {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Json)
    try {
        $value=ConvertFrom-ChatpadExactJson $Json
        [pscustomobject]@{result='PASS';result_code='JSON_VALID';value=$value;defects=@()}
    } catch {
        $message=$_.Exception.Message
        $code=if($message-match'DUPLICATE_JSON_PROPERTY'){'DUPLICATE_JSON_PROPERTY'}else{'JSON_INVALID'}
        [pscustomobject]@{result='FAIL';result_code=$code;value=$null;defects=@($message)}
    }
}

function ConvertTo-ChatpadExactCanonicalJson {
    param([Parameter(Mandatory)][object]$InputObject)
    ConvertTo-ChatpadExactCanonicalJsonNode $InputObject
}

function ConvertTo-ChatpadExactJsonString {
    param([AllowNull()][string]$Value)
    if($null-eq$Value){return 'null'}
    $builder=[Text.StringBuilder]::new()
    [void]$builder.Append('"')
    foreach($character in $Value.ToCharArray()){
        $code=[int]$character
        if($character-eq'"'){[void]$builder.Append('\"')}
        elseif($character-eq'\'){[void]$builder.Append('\\')}
        elseif($character-eq"`b"){[void]$builder.Append('\b')}
        elseif($character-eq"`f"){[void]$builder.Append('\f')}
        elseif($character-eq"`n"){[void]$builder.Append('\n')}
        elseif($character-eq"`r"){[void]$builder.Append('\r')}
        elseif($character-eq"`t"){[void]$builder.Append('\t')}
        elseif($code-lt32){[void]$builder.Append(('\u{0:x4}'-f$code))}
        else{[void]$builder.Append($character)}
    }
    [void]$builder.Append('"')
    $builder.ToString()
}

function ConvertTo-ChatpadExactCanonicalJsonNode {
    param([AllowNull()][object]$Value)
    if($null-eq$Value){return 'null'}
    if($Value-is[string]-or$Value-is[char]-or$Value-is[guid]){
        return ConvertTo-ChatpadExactJsonString ([string]$Value)
    }
    if($Value-is[datetime]-or$Value-is[datetimeoffset]){throw [ArgumentException]::new('CANONICAL_JSON_DATETIME_NOT_SUPPORTED')}
    if($Value-is[bool]){if($Value){return 'true'}else{return 'false'}}
    if($Value-is[byte]-or$Value-is[sbyte]-or$Value-is[int16]-or$Value-is[uint16]-or$Value-is[int32]-or$Value-is[uint32]-or$Value-is[int64]-or$Value-is[uint64]){
        return ([IFormattable]$Value).ToString('D',[Globalization.CultureInfo]::InvariantCulture)
    }
    if($Value-is[decimal]){
        return ([IFormattable]$Value).ToString('G29',[Globalization.CultureInfo]::InvariantCulture)
    }
    if($Value-is[single]-or$Value-is[double]){
        if([double]::IsNaN([double]$Value)-or[double]::IsInfinity([double]$Value)){throw [ArgumentException]::new('NONFINITE_JSON_NUMBER')}
        return ([IFormattable]$Value).ToString('R',[Globalization.CultureInfo]::InvariantCulture)
    }
    if($Value-is[Collections.IDictionary]){
        $parts=[Collections.Generic.List[string]]::new()
        $keys=[string[]]@($Value.Keys|ForEach-Object{[string]$_})
        [Array]::Sort($keys,[StringComparer]::Ordinal)
        foreach($key in $keys){
            $parts.Add((ConvertTo-ChatpadExactJsonString $key)+':'+(ConvertTo-ChatpadExactCanonicalJsonNode $Value[$key]))
        }
        return '{'+($parts-join',')+'}'
    }
    if($Value-is[Collections.IEnumerable]){
        $parts=[Collections.Generic.List[string]]::new()
        foreach($item in $Value){$parts.Add((ConvertTo-ChatpadExactCanonicalJsonNode $item))}
        return '['+($parts-join',')+']'
    }
    $objectParts=[Collections.Generic.List[string]]::new()
    $properties=@($Value.PSObject.Properties|Where-Object{$_.MemberType-in@('NoteProperty','Property','AliasProperty')})
    $propertyNames=[string[]]@($properties|ForEach-Object{$_.Name})
    [Array]::Sort($propertyNames,[StringComparer]::Ordinal)
    foreach($propertyName in $propertyNames){
        $property=$Value.PSObject.Properties[$propertyName]
        $objectParts.Add((ConvertTo-ChatpadExactJsonString $property.Name)+':'+(ConvertTo-ChatpadExactCanonicalJsonNode $property.Value))
    }
    '{'+($objectParts-join',')+'}'
}

function Test-ChatpadExactDeepEqual {
    param([AllowNull()][object]$Left,[AllowNull()][object]$Right)
    try {
        (ConvertTo-ChatpadExactCanonicalJson $Left)-ceq(ConvertTo-ChatpadExactCanonicalJson $Right)
    } catch {
        $false
    }
}

function Get-ChatpadExactPropertyNames {
    param([AllowNull()][object]$Object)
    if($null-eq$Object-or$Object-is[array]){return @()}
    if($Object-is[Collections.IDictionary]){return @($Object.Keys|ForEach-Object{[string]$_})}
    @($Object.PSObject.Properties|Where-Object{$_.MemberType-in@('NoteProperty','Property','AliasProperty')}|ForEach-Object{$_.Name})
}

function Test-ChatpadExactHasProperty {
    param([AllowNull()][object]$Object,[Parameter(Mandatory)][string]$Name)
    if($null-eq$Object-or$Object-is[array]){return $false}
    if($Object-is[Collections.IDictionary]){
        if($null-ne$Object.PSObject.Methods['ContainsKey']){return $Object.ContainsKey($Name)}
        return $Object.Contains($Name)
    }
    $null-ne$Object.PSObject.Properties[$Name]
}

function Test-ChatpadExactJsonObject {
    param([AllowNull()][object]$Value)
    $null-ne$Value-and$Value-isnot[array]-and$Value-isnot[string]-and(
        $Value-is[Collections.IDictionary]-or
        @($Value.PSObject.Properties|Where-Object{$_.MemberType-in@('NoteProperty','Property','AliasProperty')}).Count-gt0
    )
}

function Test-ChatpadExactInteger {
    param([AllowNull()][object]$Value,[long]$Minimum=[long]::MinValue)
    ($Value-is[byte]-or$Value-is[sbyte]-or$Value-is[int16]-or$Value-is[uint16]-or$Value-is[int32]-or$Value-is[uint32]-or$Value-is[int64])-and[long]$Value-ge$Minimum
}

function Test-ChatpadExactJsonArray {
    param([AllowNull()][object]$Value)
    $Value-is[array]-or$Value-is[Collections.IList]
}

function Test-ChatpadExactPropertyIsNull {
    param([AllowNull()][object]$Object,[Parameter(Mandatory)][string]$Name)
    if(-not(Test-ChatpadExactHasProperty $Object $Name)){return $true}
    if($Object-is[Collections.IDictionary]){return $null-eq$Object[$Name]}
    $null-eq$Object.PSObject.Properties[$Name].Value
}

function Test-ChatpadExactArrayProperty {
    param([AllowNull()][object]$Object,[Parameter(Mandatory)][string]$Name,[switch]$RequireStrings)
    if(-not(Test-ChatpadExactHasProperty $Object $Name)){return $false}
    if($Object-is[Collections.IDictionary]){
        if(-not(Test-ChatpadExactJsonArray -Value $Object[$Name])){return $false}
        if($RequireStrings-and@($Object[$Name]|Where-Object{$_-isnot[string]}).Count){return $false}
    } else {
        if(-not(Test-ChatpadExactJsonArray -Value $Object.PSObject.Properties[$Name].Value)){return $false}
        if($RequireStrings-and@($Object.PSObject.Properties[$Name].Value|Where-Object{$_-isnot[string]}).Count){return $false}
    }
    $true
}

function Add-ChatpadRequiredPropertyDefects {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Defects,
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string[]]$Required,
        [Parameter(Mandatory)][string]$Scope
    )
    foreach($name in $Required){
        if(-not(Test-ChatpadExactHasProperty $Object $name)-or(Test-ChatpadExactPropertyIsNull $Object $name)){
            $Defects.Add("schema-required-missing:$Scope.$name")
        }
    }
}

function Add-ChatpadAdditionalPropertyDefects {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[string]]$Defects,
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][string[]]$Allowed,
        [Parameter(Mandatory)][string]$Scope
    )
    foreach($name in @(Get-ChatpadExactPropertyNames $Object)){
        if($name-cnotin$Allowed){$Defects.Add("schema-additional-property:$Scope.$name")}
    }
}

function Get-ChatpadExactObjectHash {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [string[]]$ExcludedProperties=@()
    )
    $copy=Copy-ChatpadExactObject $InputObject
    foreach($name in $ExcludedProperties){
        if($copy-is[Collections.IDictionary]){
            [void]$copy.Remove($name)
        } elseif($null-ne$copy.PSObject.Properties[$name]){
            $copy.PSObject.Properties.Remove($name)
        }
    }
    Get-ChatpadExactSha256Text (ConvertTo-ChatpadExactCanonicalJson $copy)
}

function Get-ChatpadExactProperty {
    param([object]$Object,[Parameter(Mandatory)][string]$Name,[object]$Default=$null)
    if($null-eq$Object -or $Object -is [array]){return $Default}
    if($Object-is[Collections.IDictionary]){
        $contains=if($null-ne$Object.PSObject.Methods['ContainsKey']){$Object.ContainsKey($Name)}else{$Object.Contains($Name)}
        if($contains){return $Object[$Name]}
        return $Default
    }
    $property=$Object.PSObject.Properties[$Name]
    if($null-eq$property){return $Default}
    $property.Value
}

function Get-ChatpadExactRawProperty {
    param([object]$Object,[Parameter(Mandatory)][string]$Name,[object]$Default=$null)
    if($null-eq$Object-or$Object-is[array]){return $Default}
    $value=if($Object-is[Collections.IDictionary]){
        $contains=if($null-ne$Object.PSObject.Methods['ContainsKey']){$Object.ContainsKey($Name)}else{$Object.Contains($Name)}
        if(-not$contains){return $Default}
        $Object[$Name]
    } else {
        $property=$Object.PSObject.Properties[$Name]
        if($null-eq$property){return $Default}
        $property.Value
    }
    return ,$value
}

function Test-ChatpadExactGuid {
    param([object]$Value)
    $parsed=[guid]::Empty
    -not[string]::IsNullOrWhiteSpace([string]$Value) -and [guid]::TryParse([string]$Value,[ref]$parsed)
}

function ConvertTo-ChatpadCanonicalInstanceId {
    param([Parameter(Mandatory)][object]$InstanceId)
    if($InstanceId -isnot [string]){throw [ArgumentException]::new('INSTANCE_ID_TYPE_INVALID')}
    $value=[string]$InstanceId
    if($value-ne$value.Trim()){throw [ArgumentException]::new('INSTANCE_ID_WHITESPACE_INVALID')}
    if([string]::IsNullOrWhiteSpace($value)-or$value.Length-gt512){throw [ArgumentException]::new('INSTANCE_ID_LENGTH_INVALID')}
    if($value-notmatch'^[A-Za-z0-9_&\\#{}().,+:;=@%!\-]+$'){throw [ArgumentException]::new('INSTANCE_ID_CHARACTER_INVALID')}
    if($value.IndexOfAny([char[]]"*?[]")-ge0){throw [ArgumentException]::new('INSTANCE_ID_PARTIAL_OR_WILDCARD')}
    $segments=$value.Split('\')
    if($segments.Count-lt3-or@($segments|Where-Object{[string]::IsNullOrWhiteSpace($_)}).Count){throw [ArgumentException]::new('INSTANCE_ID_INCOMPLETE')}
    $value.ToUpperInvariant()
}

function Test-ChatpadCanonicalInstanceIdEqual {
    param([Parameter(Mandatory)][object]$Left,[Parameter(Mandatory)][object]$Right)
    try {
        (ConvertTo-ChatpadCanonicalInstanceId $Left) -ceq (ConvertTo-ChatpadCanonicalInstanceId $Right)
    } catch {
        $false
    }
}

function Assert-ChatpadExactSafePath {
    param([Parameter(Mandatory)][object]$Path,[switch]$MustExist)
    if($Path-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$Path)){throw [ArgumentException]::new('PATH_INVALID')}
    $value=[string]$Path
    if($value.IndexOfAny([char[]]"*?")-ge0-or$value-match'[\x00-\x1f]'){throw [ArgumentException]::new('PATH_WILDCARD_OR_CONTROL_INVALID')}
    if(-not[IO.Path]::IsPathRooted($value)){throw [ArgumentException]::new('PATH_NOT_ABSOLUTE')}
    if($value-match'(^|[\\/])\.\.?([\\/]|$)'){throw [ArgumentException]::new('PATH_TRAVERSAL_INVALID')}
    $colonCount=@($value.ToCharArray()|Where-Object{$_-eq':'}).Count
    if($colonCount-ne1-or$value.IndexOf(':')-ne1){throw [ArgumentException]::new('PATH_ALTERNATE_DATA_STREAM_INVALID')}
    $full=[IO.Path]::GetFullPath($value)
    if($MustExist-and-not(Test-Path -LiteralPath $full -PathType Leaf)){throw [IO.FileNotFoundException]::new('PATH_NOT_FOUND')}
    $probe=$full
    while($probe-and(Test-Path -LiteralPath $probe)){
        $item=Get-Item -LiteralPath $probe -Force
        if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw [ArgumentException]::new('PATH_REPARSE_POINT_INVALID')}
        $parent=Split-Path -Parent $probe
        if($parent-eq$probe){break}
        $probe=$parent
    }
    $full
}

function Test-ChatpadDriverIdentity {
    param([object]$Identity,[switch]$RequirePackagePath)
    $defects=[Collections.Generic.List[string]]::new()
    if(-not(Test-ChatpadExactJsonObject $Identity)){$defects.Add('identity-not-object');return @($defects)}
    $required=@('canonical_inf_path','package_byte_size','published_inf','original_inf','provider','description','driver_version','driver_date','signer','catalog_identity','service','driver_key','matching_id','driver_rank','driver_node_id','inf_sha256','catalog_sha256','architecture','model_id','install_section')
    Add-ChatpadRequiredPropertyDefects $defects $Identity $required 'driver_identity'
    Add-ChatpadAdditionalPropertyDefects $defects $Identity $required 'driver_identity'
    foreach($name in @('published_inf','original_inf','provider','description','driver_version','driver_date','signer','catalog_identity','service','driver_key','driver_node_id','inf_sha256','catalog_sha256','architecture','model_id','install_section','matching_id')){
        $value=Get-ChatpadExactProperty $Identity $name ''
        if($value-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$value)){$defects.Add("invalid-string:$name")}
    }
    foreach($name in @('inf_sha256','catalog_sha256')){
        if([string](Get-ChatpadExactProperty $Identity $name '')-notmatch'^[0-9a-fA-F]{64}$'){$defects.Add("invalid:$name")}
    }
    $path=Get-ChatpadExactProperty $Identity 'canonical_inf_path' ''
    if($path-isnot[string]){$defects.Add('canonical-inf-path-type-invalid')}
    elseif($RequirePackagePath){try{[void](Assert-ChatpadExactSafePath $path)}catch{$defects.Add($_.Exception.Message)}}
    $size=Get-ChatpadExactProperty $Identity 'package_byte_size' $null
    if(-not(Test-ChatpadExactInteger $size 1)){$defects.Add('package-size-invalid')}
    if(-not(Test-ChatpadExactInteger (Get-ChatpadExactProperty $Identity 'driver_rank' $null) 0)){$defects.Add('driver-rank-invalid')}
    @($defects)
}

function New-ChatpadRestorationSnapshot {
    param(
        [Parameter(Mandatory)][object]$DeviceState,
        [Parameter(Mandatory)][string]$SnapshotTimestamp
    )
    $canonical=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $DeviceState 'canonical_instance_id' '')
    $snapshot=[pscustomobject][ordered]@{
        schema_id=$script:SnapshotSchema
        canonical_json_version=$script:CanonicalJsonVersion
        canonical_instance_id=$canonical
        class_guid=[string](Get-ChatpadExactProperty $DeviceState 'class_guid' '')
        container_id=[string](Get-ChatpadExactProperty $DeviceState 'container_id' '')
        parent_instance_id=[string](Get-ChatpadExactProperty $DeviceState 'parent_instance_id' '')
        location_paths=@(Get-ChatpadExactProperty $DeviceState 'location_paths' @())
        hardware_ids=@(Get-ChatpadExactProperty $DeviceState 'hardware_ids' @())
        compatible_ids=@(Get-ChatpadExactProperty $DeviceState 'compatible_ids' @())
        device_status=[string](Get-ChatpadExactProperty $DeviceState 'device_status' '')
        problem_code=[int](Get-ChatpadExactProperty $DeviceState 'problem_code' 0)
        restart_required=[bool](Get-ChatpadExactProperty $DeviceState 'restart_required' $false)
        reboot_required=[bool](Get-ChatpadExactProperty $DeviceState 'reboot_required' $false)
        driver_identity=Copy-ChatpadExactObject (Get-ChatpadExactProperty $DeviceState 'driver_identity' ([pscustomobject]@{}))
        snapshot_timestamp=$SnapshotTimestamp
        unavailable_properties=@(Get-ChatpadExactProperty $DeviceState 'unavailable_properties' @())
        snapshot_sha256=''
    }
    $snapshot.snapshot_sha256=Get-ChatpadExactObjectHash $snapshot -ExcludedProperties @('snapshot_sha256')
    $snapshot
}

function Test-ChatpadRestorationSnapshot {
    param([object]$Snapshot)
    $defects=[Collections.Generic.List[string]]::new()
    if(-not(Test-ChatpadExactJsonObject $Snapshot)){$defects.Add('snapshot-not-object');return @($defects)}
    $allowed=@('schema_id','canonical_json_version','canonical_instance_id','class_guid','container_id','parent_instance_id','location_paths','hardware_ids','compatible_ids','device_status','problem_code','restart_required','reboot_required','driver_identity','snapshot_timestamp','unavailable_properties','snapshot_sha256')
    Add-ChatpadRequiredPropertyDefects $defects $Snapshot $allowed 'restoration_snapshot'
    Add-ChatpadAdditionalPropertyDefects $defects $Snapshot $allowed 'restoration_snapshot'
    if([string](Get-ChatpadExactProperty $Snapshot 'schema_id' '')-ne$script:SnapshotSchema){$defects.Add('snapshot-schema-invalid')}
    if([string](Get-ChatpadExactProperty $Snapshot 'canonical_json_version' '')-ne$script:CanonicalJsonVersion){$defects.Add('snapshot-canonical-json-version-invalid')}
    try{[void](ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $Snapshot 'canonical_instance_id' ''))}catch{$defects.Add($_.Exception.Message)}
    if(-not(Test-ChatpadExactGuid (Get-ChatpadExactProperty $Snapshot 'class_guid' ''))){$defects.Add('class-guid-invalid')}
    foreach($defect in @(Test-ChatpadDriverIdentity (Get-ChatpadExactProperty $Snapshot 'driver_identity' $null))){$defects.Add([string]$defect)}
    foreach($name in @('location_paths','hardware_ids','compatible_ids','unavailable_properties')){
        if(-not(Test-ChatpadExactArrayProperty $Snapshot $name -RequireStrings)){$defects.Add("snapshot-array-invalid:$name")}
    }
    if(-not(Test-ChatpadExactInteger (Get-ChatpadExactProperty $Snapshot 'problem_code' $null) 0)){$defects.Add('snapshot-problem-code-invalid')}
    foreach($name in @('restart_required','reboot_required')){if((Get-ChatpadExactProperty $Snapshot $name $null)-isnot[bool]){$defects.Add("snapshot-boolean-invalid:$name")}}
    $expected=Get-ChatpadExactObjectHash $Snapshot -ExcludedProperties @('snapshot_sha256')
    if([string](Get-ChatpadExactProperty $Snapshot 'snapshot_sha256' '')-cne$expected){$defects.Add('snapshot-hash-mismatch')}
    $timestamp=[datetimeoffset]::MinValue
    if(-not[datetimeoffset]::TryParse([string](Get-ChatpadExactProperty $Snapshot 'snapshot_timestamp' ''),[ref]$timestamp)){$defects.Add('snapshot-timestamp-invalid')}
    @($defects)
}

function Get-ChatpadDevicePreconditionFingerprint {
    param([Parameter(Mandatory)][object]$DeviceState)
    $projection=[pscustomobject][ordered]@{
        canonical_instance_id=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $DeviceState 'canonical_instance_id' '')
        class_guid=[string](Get-ChatpadExactProperty $DeviceState 'class_guid' '')
        container_id=[string](Get-ChatpadExactProperty $DeviceState 'container_id' '')
        parent_instance_id=[string](Get-ChatpadExactProperty $DeviceState 'parent_instance_id' '')
        location_paths=@(Get-ChatpadExactProperty $DeviceState 'location_paths' @())
        device_status=[string](Get-ChatpadExactProperty $DeviceState 'device_status' '')
        problem_code=[int](Get-ChatpadExactProperty $DeviceState 'problem_code' 0)
        driver_node_id=[string](Get-ChatpadExactProperty (Get-ChatpadExactProperty $DeviceState 'driver_identity' $null) 'driver_node_id' '')
        published_inf=[string](Get-ChatpadExactProperty (Get-ChatpadExactProperty $DeviceState 'driver_identity' $null) 'published_inf' '')
    }
    Get-ChatpadExactObjectHash $projection
}

function New-ChatpadExactInstancePlan {
    param(
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][ValidateSet('bind','restore')][string]$OperationType,
        [Parameter(Mandatory)][string]$GeneratedUtc,
        [Parameter(Mandatory)][string]$ExpiresUtc,
        [Parameter(Mandatory)][string]$RepositoryBranch,
        [Parameter(Mandatory)][string]$ImplementationCommit,
        [Parameter(Mandatory)][string]$HostId,
        [Parameter(Mandatory)][string]$SessionId,
        [Parameter(Mandatory)][object]$AuthorizationContext,
        [Parameter(Mandatory)][string]$RequestedInstanceId,
        [Parameter(Mandatory)][object]$DeviceState,
        [Parameter(Mandatory)][object]$TargetDriverIdentity,
        [Parameter(Mandatory)][object]$RestorationSnapshot,
        [Parameter(Mandatory)][string[]]$AuthorizedActions,
        [ValidateSet('none','exact-device-separate-authorization','reboot-never-automatic')][string]$RestartPolicy='none',
        [string[]]$StopConditions=@('target-instance-missing','target-identity-drift','package-identity-ambiguous','postcondition-unproven','restoration-driver-unavailable')
    )
    $canonical=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $DeviceState 'canonical_instance_id' '')
    $targetDefects=@(Test-ChatpadDriverIdentity $TargetDriverIdentity -RequirePackagePath)
    if($targetDefects.Count){throw [ArgumentException]::new("TARGET_IDENTITY_INVALID:$($targetDefects-join',')")}
    $snapshotDefects=@(Test-ChatpadRestorationSnapshot $RestorationSnapshot)
    if($snapshotDefects.Count){throw [ArgumentException]::new("RESTORATION_SNAPSHOT_INVALID:$($snapshotDefects-join',')")}
    $targetPath=Assert-ChatpadExactSafePath (Get-ChatpadExactProperty $TargetDriverIdentity 'canonical_inf_path' '')
    $plan=[pscustomobject][ordered]@{
        schema_id=$script:PlanSchema
        schema_version=1
        canonical_json_version=$script:CanonicalJsonVersion
        operation_id=$OperationId
        operation_type=$OperationType
        generated_utc=$GeneratedUtc
        expires_utc=$ExpiresUtc
        repository_branch=$RepositoryBranch
        implementation_commit=$ImplementationCommit
        host_identity=$HostId
        session_identity=$SessionId
        authorization_context=Copy-ChatpadExactObject $AuthorizationContext
        requested_instance_id=$RequestedInstanceId
        canonical_instance_id=$canonical
        device_class_guid=[string](Get-ChatpadExactProperty $DeviceState 'class_guid' '')
        container_id=[string](Get-ChatpadExactProperty $DeviceState 'container_id' '')
        parent_instance_id=[string](Get-ChatpadExactProperty $DeviceState 'parent_instance_id' '')
        location_paths=@(Get-ChatpadExactProperty $DeviceState 'location_paths' @())
        hardware_ids=@(Get-ChatpadExactProperty $DeviceState 'hardware_ids' @())
        compatible_ids=@(Get-ChatpadExactProperty $DeviceState 'compatible_ids' @())
        current_device_status=[string](Get-ChatpadExactProperty $DeviceState 'device_status' '')
        current_problem_code=[int](Get-ChatpadExactProperty $DeviceState 'problem_code' 0)
        current_driver_identity=Copy-ChatpadExactObject (Get-ChatpadExactProperty $DeviceState 'driver_identity' $null)
        target_package_path=$targetPath
        target_package_byte_size=[long](Get-ChatpadExactProperty $TargetDriverIdentity 'package_byte_size' 0)
        target_package_sha256=[string](Get-ChatpadExactProperty $TargetDriverIdentity 'inf_sha256' '')
        target_driver_identity=Copy-ChatpadExactObject $TargetDriverIdentity
        expected_post_bind_driver_identity=Copy-ChatpadExactObject $TargetDriverIdentity
        restoration_snapshot=Copy-ChatpadExactObject $RestorationSnapshot
        exact_restoration_driver_identity=Copy-ChatpadExactObject (Get-ChatpadExactProperty $RestorationSnapshot 'driver_identity' $null)
        precondition_fingerprint=Get-ChatpadDevicePreconditionFingerprint $DeviceState
        restoration_snapshot_fingerprint=[string](Get-ChatpadExactProperty $RestorationSnapshot 'snapshot_sha256' '')
        authorized_actions=@($AuthorizedActions)
        expected_restart_reboot_policy=$RestartPolicy
        stop_conditions=@($StopConditions)
        plan_sha256=''
    }
    $plan.plan_sha256=Get-ChatpadExactObjectHash $plan -ExcludedProperties @('plan_sha256')
    $plan
}

function Test-ChatpadExactInstancePlan {
    param(
        [object]$Plan,
        [string]$ExpectedPlanSha256='',
        [string]$ExpectedOperationId='',
        [string]$ValidationTimeUtc=''
    )
    $defects=[Collections.Generic.List[string]]::new()
    if(-not(Test-ChatpadExactJsonObject $Plan)){$defects.Add('plan-not-object');return [pscustomobject]@{result='FAIL';result_code='PLAN_INVALID';defects=@($defects)}}
    $allowed=@(
        'schema_id','schema_version','canonical_json_version','operation_id','operation_type','generated_utc','expires_utc',
        'repository_branch','implementation_commit','host_identity','session_identity','authorization_context',
        'requested_instance_id','canonical_instance_id','device_class_guid','container_id','parent_instance_id',
        'location_paths','hardware_ids','compatible_ids','current_device_status','current_problem_code',
        'current_driver_identity','target_package_path','target_package_byte_size','target_package_sha256',
        'target_driver_identity','expected_post_bind_driver_identity','restoration_snapshot',
        'exact_restoration_driver_identity','precondition_fingerprint','restoration_snapshot_fingerprint',
        'authorized_actions','expected_restart_reboot_policy','stop_conditions','plan_sha256'
    )
    Add-ChatpadRequiredPropertyDefects $defects $Plan $allowed 'plan'
    Add-ChatpadAdditionalPropertyDefects $defects $Plan $allowed 'plan'
    if([string](Get-ChatpadExactProperty $Plan 'schema_id' '')-ne$script:PlanSchema){$defects.Add('plan-schema-invalid')}
    if(-not(Test-ChatpadExactInteger (Get-ChatpadExactProperty $Plan 'schema_version' $null) 1)-or[long](Get-ChatpadExactProperty $Plan 'schema_version' 0)-ne1){$defects.Add('plan-version-invalid')}
    if([string](Get-ChatpadExactProperty $Plan 'canonical_json_version' '')-ne$script:CanonicalJsonVersion){$defects.Add('plan-canonical-json-version-invalid')}
    if(-not(Test-ChatpadExactGuid (Get-ChatpadExactProperty $Plan 'operation_id' ''))){$defects.Add('operation-id-invalid')}
    if($ExpectedOperationId-and[string](Get-ChatpadExactProperty $Plan 'operation_id' '')-cne$ExpectedOperationId){$defects.Add('operation-id-mismatch')}
    try {
        $requested=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $Plan 'requested_instance_id' '')
        $canonical=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $Plan 'canonical_instance_id' '')
        if($requested-cne$canonical){$defects.Add('canonical-instance-mismatch')}
        $snapshotId=ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty (Get-ChatpadExactProperty $Plan 'restoration_snapshot' $null) 'canonical_instance_id' '')
        if($snapshotId-cne$canonical){$defects.Add('snapshot-instance-mismatch')}
    } catch {$defects.Add($_.Exception.Message)}
    foreach($name in @('repository_branch','host_identity','session_identity','current_device_status')){
        $value=Get-ChatpadExactRawProperty $Plan $name $null
        if($value-isnot[string]-or[string]::IsNullOrWhiteSpace([string]$value)){$defects.Add("plan-string-invalid:$name")}
    }
    if([string](Get-ChatpadExactProperty $Plan 'repository_branch' '')-notmatch'^[A-Za-z0-9._/-]+$'){$defects.Add('repository-branch-invalid')}
    if([string](Get-ChatpadExactProperty $Plan 'implementation_commit' '')-notmatch'^[0-9a-f]{40}$'){$defects.Add('implementation-commit-invalid')}
    if(-not(Test-ChatpadExactGuid (Get-ChatpadExactProperty $Plan 'device_class_guid' ''))){$defects.Add('device-class-guid-invalid')}
    if(-not(Test-ChatpadExactInteger (Get-ChatpadExactProperty $Plan 'current_problem_code' $null) 0)){$defects.Add('current-problem-code-invalid')}
    foreach($name in @('location_paths','hardware_ids','compatible_ids','authorized_actions','stop_conditions')){
        if(-not(Test-ChatpadExactArrayProperty $Plan $name -RequireStrings)){$defects.Add("plan-array-invalid:$name")}
    }
    try{[void](Assert-ChatpadExactSafePath (Get-ChatpadExactProperty $Plan 'target_package_path' ''))}catch{$defects.Add($_.Exception.Message)}
    if(-not(Test-ChatpadExactInteger (Get-ChatpadExactProperty $Plan 'target_package_byte_size' $null) 1)){$defects.Add('target-package-size-invalid')}
    foreach($name in @('precondition_fingerprint','restoration_snapshot_fingerprint','target_package_sha256','plan_sha256')){
        if([string](Get-ChatpadExactProperty $Plan $name '')-notmatch'^[0-9a-f]{64}$'){$defects.Add("plan-hash-field-invalid:$name")}
    }
    foreach($name in @('current_driver_identity','target_driver_identity','expected_post_bind_driver_identity','exact_restoration_driver_identity')){
        foreach($defect in @(Test-ChatpadDriverIdentity (Get-ChatpadExactProperty $Plan $name $null) -RequirePackagePath)){$defects.Add("$name`:$defect")}
    }
    $snapshot=Get-ChatpadExactProperty $Plan 'restoration_snapshot' $null
    foreach($defect in @(Test-ChatpadRestorationSnapshot $snapshot)){$defects.Add([string]$defect)}
    $snapshotIdentity=Get-ChatpadExactProperty $snapshot 'driver_identity' $null
    $planRestoreIdentity=Get-ChatpadExactProperty $Plan 'exact_restoration_driver_identity' $null
    if(-not(Test-ChatpadExactDeepEqual $snapshotIdentity $planRestoreIdentity)){$defects.Add('RESTORATION_IDENTITY_SNAPSHOT_MISMATCH')}
    if(-not(Test-ChatpadExactDeepEqual (Get-ChatpadExactProperty $Plan 'target_driver_identity' $null) (Get-ChatpadExactProperty $Plan 'expected_post_bind_driver_identity' $null))){$defects.Add('expected-post-bind-identity-mismatch')}
    if([string](Get-ChatpadExactProperty $Plan 'restoration_snapshot_fingerprint' '')-cne[string](Get-ChatpadExactProperty $snapshot 'snapshot_sha256' '')){$defects.Add('restoration-snapshot-fingerprint-mismatch')}
    $target=Get-ChatpadExactProperty $Plan 'target_driver_identity' $null
    if([string](Get-ChatpadExactProperty $Plan 'target_package_path' '')-cne[string](Get-ChatpadExactProperty $target 'canonical_inf_path' '')){$defects.Add('target-package-path-identity-mismatch')}
    if([long](Get-ChatpadExactProperty $Plan 'target_package_byte_size' 0)-ne[long](Get-ChatpadExactProperty $target 'package_byte_size' -1)){$defects.Add('target-package-size-identity-mismatch')}
    if([string](Get-ChatpadExactProperty $Plan 'target_package_sha256' '')-cne[string](Get-ChatpadExactProperty $target 'inf_sha256' '')){$defects.Add('target-package-hash-identity-mismatch')}
    $operationType=[string](Get-ChatpadExactProperty $Plan 'operation_type' '')
    if($operationType-notin@('bind','restore')){$defects.Add('operation-type-invalid')}
    $actions=@(Get-ChatpadExactProperty $Plan 'authorized_actions' @())
    if($actions.Count-eq0-or@($actions|Where-Object{$_-notin$script:AllowedActions}).Count-or@($actions|Select-Object -Unique).Count-ne$actions.Count){$defects.Add('authorized-actions-invalid')}
    $requiredAction=if($operationType-eq'restore'){'restore-exact-device'}else{'bind-exact-device'}
    $forbiddenAction=if($operationType-eq'restore'){'bind-exact-device'}else{'restore-exact-device'}
    if($actions-notcontains$requiredAction-or$actions-contains$forbiddenAction){$defects.Add('operation-actions-mismatch')}
    $stops=@(Get-ChatpadExactProperty $Plan 'stop_conditions' @())
    if($stops.Count-eq0-or@($stops|Where-Object{[string]::IsNullOrWhiteSpace([string]$_)}).Count-or@($stops|Select-Object -Unique).Count-ne$stops.Count){$defects.Add('stop-conditions-invalid')}
    $authorization=Get-ChatpadExactProperty $Plan 'authorization_context' $null
    if(-not(Test-ChatpadExactJsonObject $authorization)){$defects.Add('authorization-context-invalid')}
    else {
        Add-ChatpadRequiredPropertyDefects $defects $authorization @('source','synthetic') 'authorization_context'
        Add-ChatpadAdditionalPropertyDefects $defects $authorization @('source','synthetic') 'authorization_context'
        if([string](Get-ChatpadExactProperty $authorization 'source' '')-ne'offline-synthetic-suite'-or(Get-ChatpadExactProperty $authorization 'synthetic' $null)-isnot[bool]-or-not[bool](Get-ChatpadExactProperty $authorization 'synthetic' $false)){$defects.Add('authorization-context-not-offline-synthetic')}
    }
    $actualHash=Get-ChatpadExactObjectHash $Plan -ExcludedProperties @('plan_sha256')
    if([string](Get-ChatpadExactProperty $Plan 'plan_sha256' '')-cne$actualHash){$defects.Add('plan-hash-invalid')}
    if($ExpectedPlanSha256-and$ExpectedPlanSha256-cne$actualHash){$defects.Add('plan-hash-mismatch')}
    $generated=[datetimeoffset]::MinValue;$expires=[datetimeoffset]::MinValue;$now=[datetimeoffset]::UtcNow
    if(-not[datetimeoffset]::TryParse([string](Get-ChatpadExactProperty $Plan 'generated_utc' ''),[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$generated)){$defects.Add('generated-time-invalid')}
    if(-not[datetimeoffset]::TryParse([string](Get-ChatpadExactProperty $Plan 'expires_utc' ''),[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$expires)){$defects.Add('expiry-time-invalid')}
    if($ValidationTimeUtc-and-not[datetimeoffset]::TryParse($ValidationTimeUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$now)){$defects.Add('validation-time-invalid')}
    if($expires-le$generated){$defects.Add('expiry-order-invalid')}
    if($expires-le$now){$defects.Add('plan-expired')}
    if($defects.Count){[pscustomobject]@{result='FAIL';result_code=if($defects-contains'RESTORATION_IDENTITY_SNAPSHOT_MISMATCH'){'RESTORATION_IDENTITY_SNAPSHOT_MISMATCH'}elseif($defects-contains'plan-expired'){'PLAN_EXPIRED'}elseif($defects-contains'plan-hash-mismatch'-or$defects-contains'plan-hash-invalid'){'PLAN_HASH_MISMATCH'}elseif($defects-contains'operation-id-mismatch'){'OPERATION_ID_MISMATCH'}else{'PLAN_SCHEMA_INVALID'};defects=@($defects)}}
    else{[pscustomobject]@{result='PASS';result_code='PLAN_VALID';defects=@()}}
}

function Test-ChatpadExactTransition {
    param([Parameter(Mandatory)][string]$From,[Parameter(Mandatory)][string]$To)
    if(-not$script:AllowedTransitions.Contains($From)){return $false}
    $script:AllowedTransitions[$From]-contains$To
}

function Add-ChatpadExactTransition {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][Collections.Generic.List[object]]$Transitions,
        [Parameter(Mandatory)][string]$State,
        [Parameter(Mandatory)][string]$Timestamp,
        [string]$Reason=''
    )
    if($Transitions.Count){
        $prior=[string]$Transitions[$Transitions.Count-1].state
        if(-not(Test-ChatpadExactTransition $prior $State)){throw [InvalidOperationException]::new("STATE_TRANSITION_INVALID:$prior->$State")}
    } elseif($State-ne'PLAN_CREATED'){throw [InvalidOperationException]::new("STATE_TRANSITION_INVALID:<start>->$State")}
    $Transitions.Add([pscustomobject][ordered]@{sequence=$Transitions.Count+1;state=$State;timestamp=$Timestamp;reason=$Reason})
}

function Test-ChatpadRealExecutionAuthorization {
    param(
        [Parameter(Mandatory)][ValidateSet('Apply','Restore')][string]$Mode,
        [object]$Plan,
        [string]$ExpectedPlanSha256,
        [string]$OperationId,
        [string]$AuthorizationValue,
        [switch]$AllowWindowsMutation,
        [bool]$IsElevated,
        [string]$AdapterIdentity,
        [bool]$SyntheticAdapter,
        [bool]$CleanPreflight,
        [string]$ValidationTimeUtc
    )
    $defects=[Collections.Generic.List[string]]::new()
    $validation=Test-ChatpadExactInstancePlan $Plan -ExpectedPlanSha256 $ExpectedPlanSha256 -ExpectedOperationId $OperationId -ValidationTimeUtc $ValidationTimeUtc
    if($validation.result-ne'PASS'){$defects.Add($validation.result_code)}
    $defects.Add($script:LiveAdapterBlocker)
    [pscustomobject]@{
        result='BLOCKED'
        result_code=$script:LiveAdapterBlocker
        defects=@($defects)
        caller_execution_claims_trusted=$false
        live_adapter_capability_present=$false
    }
}

function Test-ChatpadExactInstanceEvidence {
    param(
        [object]$Evidence,
        [ValidateSet('OfflineSyntheticFramework')][string]$TrustedValidationContext='OfflineSyntheticFramework'
    )
    $defects=[Collections.Generic.List[string]]::new()
    if(-not(Test-ChatpadExactJsonObject $Evidence)){$defects.Add('evidence-not-object')}
    else {
        $required=@(
            'schema_id','canonical_json_version','producer','evidence_mode','operation_id','plan_sha256','implementation_commit',
            'adapter_identity','adapter_mode','synthetic','source_classification','target_instance_id','preconditions',
            'state_transitions','adapter_calls','before_driver_identity','after_driver_identity','restart_required','reboot_required',
            'mutation_attempt_count','synthetic_exact_binding_attempt_count','synthetic_exact_successful_binding_count',
            'synthetic_exact_restoration_attempt_count','synthetic_exact_successful_restoration_count','synthetic_restart_attempt_count',
            'live_exact_binding_operation_count','live_exact_restoration_operation_count','live_restart_operation_count',
            'broad_installation_attempt_count','broad_rollback_attempt_count','live_operation_count','windows_mutation_count',
            'controlled_failure_count','uncontrolled_exception_count','exception_type','verification_result','result_code',
            'stop_condition','restoration_outcome','restoration_identity','mutation_may_have_occurred','uncertainty_status',
            'final_classification','live_readiness_satisfied',
            'readiness','current_gate','capability_blocker'
        )
        Add-ChatpadRequiredPropertyDefects $defects $Evidence $required 'evidence'
        Add-ChatpadAdditionalPropertyDefects $defects $Evidence $required 'evidence'
        if([string](Get-ChatpadExactProperty $Evidence 'schema_id' '')-ne$script:EvidenceSchema){$defects.Add('evidence-schema-invalid')}
        if([string](Get-ChatpadExactProperty $Evidence 'canonical_json_version' '')-ne$script:CanonicalJsonVersion){$defects.Add('evidence-canonical-json-version-invalid')}
        if(-not(Test-ChatpadExactGuid (Get-ChatpadExactProperty $Evidence 'operation_id' ''))){$defects.Add('operation-id-invalid')}
        if([string](Get-ChatpadExactProperty $Evidence 'plan_sha256' '')-notmatch'^[0-9a-f]{64}$'){$defects.Add('plan-hash-invalid')}
        if([string](Get-ChatpadExactProperty $Evidence 'implementation_commit' '')-notmatch'^[0-9a-f]{40}$'){$defects.Add('implementation-commit-invalid')}
        $synthetic=Get-ChatpadExactProperty $Evidence 'synthetic' $null
        $adapter=[string](Get-ChatpadExactProperty $Evidence 'adapter_identity' '')
        $source=[string](Get-ChatpadExactProperty $Evidence 'source_classification' '')
        if($TrustedValidationContext-ne'OfflineSyntheticFramework'){$defects.Add('UNTRUSTED_EVIDENCE_ORIGIN')}
        if($synthetic-isnot[bool]-or-not[bool]$synthetic-or$source-ne'synthetic'-or$adapter-ne'chatpad-fake-exact-instance-adapter-v1'-or
            [string](Get-ChatpadExactProperty $Evidence 'adapter_mode' '')-ne'offline-fake'-or
            [string](Get-ChatpadExactProperty $Evidence 'producer' '')-ne'tools/ExactInstance/ChatpadExactInstance.Orchestrator.psm1'-or
            [string](Get-ChatpadExactProperty $Evidence 'evidence_mode' '')-ne'offline-synthetic'){
            $defects.Add('UNTRUSTED_EVIDENCE_ORIGIN')
        }
        if([bool](Get-ChatpadExactProperty $Evidence 'live_readiness_satisfied' $true)){$defects.Add('synthetic-evidence-cannot-satisfy-live-readiness')}
        foreach($name in @('live_exact_binding_operation_count','live_exact_restoration_operation_count','live_restart_operation_count','live_operation_count','windows_mutation_count')){
            $value=Get-ChatpadExactProperty $Evidence $name $null
            if(-not(Test-ChatpadExactInteger $value 0)-or[long]$value-ne0){$defects.Add("live-counter-nonzero:$name")}
        }
        foreach($name in @('mutation_attempt_count','synthetic_exact_binding_attempt_count','synthetic_exact_successful_binding_count','synthetic_exact_restoration_attempt_count','synthetic_exact_successful_restoration_count','synthetic_restart_attempt_count','broad_installation_attempt_count','broad_rollback_attempt_count','controlled_failure_count','uncontrolled_exception_count')){
            if(-not(Test-ChatpadExactInteger (Get-ChatpadExactProperty $Evidence $name $null) 0)){$defects.Add("evidence-count-invalid:$name")}
        }
        try{[void](ConvertTo-ChatpadCanonicalInstanceId (Get-ChatpadExactProperty $Evidence 'target_instance_id' ''))}catch{$defects.Add($_.Exception.Message)}
        if(-not(Test-ChatpadExactArrayProperty $Evidence 'state_transitions')-or@(Get-ChatpadExactProperty $Evidence 'state_transitions' @()).Count-eq0){$defects.Add('state-transitions-invalid')}
        if(-not(Test-ChatpadExactArrayProperty $Evidence 'adapter_calls')){$defects.Add('adapter-calls-invalid')}
        if([string](Get-ChatpadExactProperty $Evidence 'readiness' '')-ne'BLOCKED'){$defects.Add('readiness-not-blocked')}
        if([string](Get-ChatpadExactProperty $Evidence 'current_gate' '')-ne$script:PendingAuditBlocker){$defects.Add('compile-only-validation-gate-missing')}
        if([string](Get-ChatpadExactProperty $Evidence 'capability_blocker' '')-ne$script:LiveAdapterBlocker){$defects.Add('native-adapter-execution-blocker-missing')}
        $uncertainty=[string](Get-ChatpadExactProperty $Evidence 'uncertainty_status' '')
        if($uncertainty-notin@('none','active','recovered')){$defects.Add('uncertainty-status-invalid')}
        if((Get-ChatpadExactProperty $Evidence 'mutation_may_have_occurred' $null)-isnot[bool]){$defects.Add('mutation-uncertainty-boolean-invalid')}
        if($uncertainty-eq'active'-and(
            [string](Get-ChatpadExactProperty $Evidence 'final_classification' '')-eq'PASS'-or
            @(Get-ChatpadExactProperty $Evidence 'state_transitions' @()|Where-Object{$_.state-eq'COMPLETED'}).Count
        )){$defects.Add('active-uncertainty-cannot-complete')}
    }
    if($defects.Count){[pscustomobject]@{result='FAIL';result_code='EVIDENCE_PROVENANCE_INVALID';defects=@($defects)}}
    else{[pscustomobject]@{result='PASS';result_code='EVIDENCE_VALID';defects=@()}}
}

function Get-ChatpadExactInstanceConstants {
    [pscustomobject][ordered]@{
        plan_schema=$script:PlanSchema
        snapshot_schema=$script:SnapshotSchema
        evidence_schema=$script:EvidenceSchema
        pending_audit_blocker=$script:PendingAuditBlocker
        live_adapter_blocker=$script:LiveAdapterBlocker
        canonical_json_version=$script:CanonicalJsonVersion
        allowed_modes=@($script:AllowedModes)
        allowed_actions=@($script:AllowedActions)
        allowed_transitions=$script:AllowedTransitions
    }
}

Export-ModuleMember -Function *-Chatpad*
