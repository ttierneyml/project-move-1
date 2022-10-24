xquery version "1.0-ml";
declare namespace http = "xdmp:http";

declare variable $URI as xs:string external;  

declare function local:formatXML($source, $meta, $xhtml, $date, $countryCode, $long, $lat, $formatted-date, $responseCode, $domain){
    let $doc := 
        <envelope>
            <headers>
                <date>{$date}</date>
                <countryCode>{$countryCode}</countryCode>
                <formatted-date>{$formatted-date}</formatted-date>
                <long>{$long}</long>
                <lat>{$lat}</lat>
                {if($responseCode = "") then (<httpGetError>true</httpGetError>) else (<responseCode>{$responseCode}</responseCode>)}
                <domain>{$domain}</domain>
                <metadata>{$meta}</metadata>    
            </headers>
            <instance>
                <article>{$xhtml//*:html}</article>
                <source>{$source}</source> 
            </instance>
        </envelope>
    return $doc
};

declare function local:formatDate($date){
    let $month := xdmp:month-name-from-date($date)
    let $day := fn:substring($date, 9, 2)
    let $year := fn:substring($date, 1, 4)
    let $formatted-date := fn:concat($month, " ", $day, ", ", $year)
    return $formatted-date
};

declare function local:httpGetRecur($i, $source, $date, $countryCode, $long, $lat, $formatted-date, $domain, $URI){
    let $url := $i
    return  try{
                let $html := xdmp:http-get($url,
                    <options xmlns="xdmp:http">
                        <verify-cert>false</verify-cert>
                    </options>)
                let $xhtml := xdmp:tidy($html[2])
                let $meta := $html[1]
                let $responseCode := $meta/http:code/text()
                let $ret := if(xs:int($responseCode) = 301 or xs:int($responseCode) = 302) then local:httpGetRecur($url, $source, $date, $countryCode, $long, $lat, $formatted-date, $domain, $URI) else xdmp:document-insert($URI, local:formatXML($source, $meta, $xhtml, $date, $countryCode, $long, $lat, $formatted-date, $responseCode, $domain), (xdmp:permission("rest-reader", "read"), xdmp:permission("rest-writer", "update")), ("canonical", "corb_transformed"))
                return $ret
            }
            catch($err){
                let $xhtml := <error>HTML UNRETRIEVABLE. SEE METADATA SECTION FOR ERROR</error>
                return xdmp:document-insert($URI, local:formatXML($source, $err, $xhtml, $date, $countryCode, $long, $lat, $formatted-date, "", $domain), (xdmp:permission("rest-reader", "read"), xdmp:permission("rest-writer", "update")), ("corb_transformed", "failed"))
            }
};

let $source := fn:doc($URI)
let $url := $source//root/SOURCEURL/text()
let $domain := fn:tokenize($url, "/")[3]
let $SQLDATE := $source//root/SQLDATE/text()
let $year := fn:substring($SQLDATE, 1, 4)
let $month := fn:substring($SQLDATE, 5, 2)
let $day := fn:substring($SQLDATE, 7, 2)
let $date := xs:date(fn:concat($year, "-", $month, "-", $day))
let $formatted-date := local:formatDate(<date>{$date}</date>)
let $countryCode := if(fn:normalize-space($source//ActionGeo_CountryCode/text()) = "")
                    then "Null-Island"
                    else $source//ActionGeo_CountryCode/text()
let $long := if(fn:normalize-space($source//ActionGeo_Long/text()) = "")
            then 0
            else $source//ActionGeo_Long/text()
let $lat := if(fn:normalize-space($source//ActionGeo_Lat/text()) = "")
            then 0
            else $source//ActionGeo_Lat/text()
return local:httpGetRecur($url, $source, $date, $countryCode, $long, $lat, $formatted-date, $domain, $URI)