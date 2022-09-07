xquery version "1.0-ml";

declare namespace http = "xdmp:http";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";
import module namespace search = "http://marklogic.com/appservices/search" at "/MarkLogic/appservices/search/search.xqy";
declare variable $total := fn:count(local:totalArticles());
declare variable $query := local:setQuery();
declare variable $sort := "date";
declare variable $start := if(xdmp:get-request-field("page"))
                            then ((xs:int(xdmp:get-request-field("page")) - 1) * 15)
                            else 1;
declare variable $results := search:search($query, $options, $start, 15)
declare variable $resultTotal := fn:data($results/@total);(:fn:count(local:results-controller());:)


declare variable $options :=
    <options xmlns="http://marklogic.com/appservices/search">
        <search:operator name="sort">
            <search:state name="date">
                <search:sort-order direction="ascending" type="xs:date">
                    <search:element name="date"/>
                </search:sort-order>
                <search:sort-order>
                    <search:score/>
                </search:sort-order>
            </search:state>            
            <search:state name="countryCode">
                <search:sort-order direction="ascending" type="xs:string">
                    <search:element name="countryCode"/>
                </search:sort-order>
                <search:sort-order>
                    <search:score/>
                </search:sort-order>
            </search:state>   
        </search:operator>
        <constraint name="Country">
            <range type="xs:string" collation="http://marklogic.com/collation/en/S1">
                <element name="countryCode"/>
                <facet-option>limit=10</facet-option>
                <facet-option>frequency-order</facet-option>
                <facet-option>descending</facet-option>
            </range>
        </constraint>
        <constraint name="Response">
            <range type="xs:int">
                <element name="responseCode"/>
                <facet-option>limit=10</facet-option>
                <facet-option>frequency-order</facet-option>
                <facet-option>descending</facet-option>
            </range>
        </constraint>
        <constraint name="Domain">
            <range type="xs:string" collation="http://marklogic.com/collation/en/S1">
                <element name="domain"/>
                <facet-option>limit=10</facet-option>
                <facet-option>frequency-order</facet-option>
                <facet-option>descending</facet-option>
            </range>
        </constraint>
    </options>;

declare function local:totalArticles(){
    for $doc in fn:doc()
    return $doc
};

declare function local:setQuery(){
    let $q := if(xdmp:get-request-field("query"))
            then xdmp:get-request-field("query")
            else ()
    let $s := if(xdmp:get-request-field("sortby"))
            then fn:concat("sort:", xdmp:get-request-field("sortby"))
            else ()
    let $f := local:join($q, local:addConstraints("Country"))
    let $f := local:join($f, local:addConstraints("Response")) 
    let $f := local:join($f, local:addConstraints("Domain")) 
    return if(fn:empty($f)) then () else fn:concat($f, " ", $s)
};

declare function local:join($a, $b){
    let $ret := if($a) 
                then if($b)
                    then fn:concat($a, " AND ", $b)
                    else $a
                else $b
    return $ret
};

declare function local:addConstraints($constraint){
    let $f :=   if(xdmp:get-request-field($constraint))
                then    let $tokens := fn:tokenize(xdmp:get-request-field($constraint), "/")
                        let $count := fn:count($tokens)
                        for $token in $tokens
                        where $token != ""
                        return  fn:concat($constraint, ":", $token)
                else ()
    return if(fn:empty($f)) then () else fn:string-join($f, " OR ")
};

declare function local:getURL(){
    let $q := xdmp:get-request-field("query")
    let $s := xdmp:get-request-field("sortby")
    let $rCode := xdmp:get-request-field("Response")
    let $cCode := xdmp:get-request-field("Country")
    let $domain := xdmp:get-request-field("Domain")
    let $page := xdmp:get-request-field("page")
    let $url := fn:concat("/index.xqy?query=", $q, "&amp;sortby=", $s, "&amp;", xdmp:url-encode("Response"), "=", $rCode, "&amp;", xdmp:url-encode("Country"), "=", $cCode, "&amp;Domain=", $domain, "&amp;page=", $page)
    return $url
};

declare function local:setURL($sort){
    let $currURL := local:getURL()
    let $currsort := fn:concat("sortby=", xdmp:get-request-field("sortby"))
    let $newSort := fn:concat("sortby=", $sort)
    let $updatedURL := fn:replace($currURL, $currsort, $newSort)
    return $updatedURL
};

declare function local:addFacetsURL($facetType, $facet){
    let $currURL := local:getURL()
    let $currFacets := xdmp:get-request-field($facetType)
    let $updatedURL := if(fn:contains($currFacets, $facet))
                        then let $target := fn:concat($facet, "/")
                            let $updatedFacets := fn:replace($currFacets, $target, "")
                            return if($updatedFacets)
                                    then fn:replace($currURL, fn:concat($facetType, "=", $currFacets), fn:concat($facetType, "=", $updatedFacets))
                                    else fn:replace($currURL, fn:concat($facetType, "=", $currFacets), fn:concat($facetType, "="))
                        else let $facets := fn:concat($currFacets, $facet, "/")
                            return fn:replace($currURL, fn:concat($facetType, "=", $currFacets), fn:concat($facetType, "=", $facets))
    return $updatedURL
};

declare function local:setPageURL($p){
    let $currURL := local:getURL()
    let $currP := xdmp:get-request-field("page")
    let $newURL := fn:replace($currURL, fn:concat("page=", $currP), fn:concat("page=", $p))
    return $newURL
};

declare function local:display-results(){
    let $docs := for $i in $results/search:result
                let $uri := fn:data($i/@uri)
                let $doc := fn:doc($uri)
                return $doc
    return if($docs)
            then(
                <div id="content">
                    <table cellspacing="0" width="700px">
                        <tr>
                            <th width="20px">ID</th>
                            <th width="200px">Title</th>
                            <th width="70px"><a href="{local:setURL("date")}" class="button">Date</a></th>
                            <th width="70px"><a href="{local:setURL("countryCode")}" class="button">Country Code</a></th>
                            <th width="40px">Latitude</th>
                            <th width="40px">Longitude</th>
                        </tr>

                        {let $sortedDocs := $docs
                        for $doc in $sortedDocs
                        let $id := $doc//GLOBALEVENTID/text()
                        let $formatted-date := $doc//formatted-date
                        let $countryCode := $doc//countryCode
                        let $title := fn:substring($doc//xhtml:html/xhtml:head/xhtml:title[1]/string(), 1, 100)
                        let $lat := $doc/envelope/headers/lat
                        let $long := $doc/envelope/headers/long
                        let $link := $doc//SOURCEURL
                        where $title != ""
                        return( <tr>
                                    <td colspan="10"><hr/></td>
                                </tr>,

                                <tr>
                                    <td><b>{$id}</b></td>
                                    <td><a width="200px" overflowWrap="break-word" inlineSize="200px" href="{$link}">{$title}</a></td>
                                    <td><b>{$formatted-date}</b></td>
                                    <td><b>{$countryCode}</b></td>
                                    <td><b>{$lat}</b></td>
                                    <td><b>{$long}</b></td>
                                </tr>
                        )}
                    </table>
                </div>
            )
            else <div>Sorry, no results for your search.<br/><br/><br/></div>
};

declare function local:facets(){
    let $q := if(xdmp:get-request-field("query")) then xdmp:get-request-field("query") else " "
    for $facet in search:search($q, $options)/search:facet
    let $facet-count := fn:count($facet/search:facet-value)
    let $facet-name := fn:data($facet/@name)
    return  <div>
                <h3>{$facet-name}</h3>
                {
                    for $option in $facet/search:facet-value
                    let $option-name := $option/@name
                    return <div id="facet"><a href="{local:addFacetsURL($facet-name, $option-name)}">{fn:data($option/@name)}</a><a> [{fn:data($option/@count)}]</a></div>
                }
            </div>
};

declare function local:displayPagination(){
    let $p := if(xdmp:get-request-field("page"))
                then xdmp:get-request-field("page")
                else 0
    let $a := if(xs:int($p) > 3) then (xs:int($p) - 2) else 1
    let $b := if(xs:int($p) > 3) then (xs:int($p) - 1) else 2
    let $c := if(xs:int($p) > 3) then xs:int($p) else 3
    let $d := if(xs:int($p) > 3) then (xs:int($p) + 1) else 4
    let $e := if(xs:int($p) > 3) then (xs:int($p) + 2) else 5

    return (
        <div>
            <a class="pageLink" href="{local:setPageURL($a)}">{$a}</a>&nbsp;
            <a class="pageLink" href="{local:setPageURL($b)}">{$b}</a>&nbsp;
            <a class="pageLink" href="{local:setPageURL($c)}">{$c}</a>&nbsp;
            <a class="pageLink" href="{local:setPageURL($d)}">{$d}</a>&nbsp;
            <a class="pageLink" href="{local:setPageURL($e)}">{$e}</a>&nbsp;
        </div>
    )
};

xdmp:set-response-content-type("text/html; charset=utf-8"),
let $query := try {
    local:setQuery()
} catch($e) {
    xdmp:log("setQuery Exception: " || xdmp:describe($e, (), ()))
}
return
<html>
    <head>
        <title>Project Move</title>
    <link href="css/project-move.css" rel="stylesheet" type="text/css" />
    </head>
    <body>
        <div id="wrapper">
            <div>
                <h3>total articles: {$total}</h3>
                <h3>results: {$resultTotal}</h3>
                {local:setQuery()}
            </div>
            {local:addConstraints("Country")}
            <div id="input">
                <form id="sinput" onsubmit="{local:getURL()}">
                    <input type="text" name="query" id="query" size="55" onsubmit="{local:getURL()}" value="{xdmp:get-request-field("query")}"/><button type="button" id="reset_button" onclick="document.location.href='index.xqy'">x</button>&#160;
                    <button type="submit" onsubmit="{local:getURL()}" href="{local:getURL()}">search</button>
                </form>
                <div id="pinput">
                    {local:displayPagination()}
                </div>
            </div>
            <div id="display">
                <div id="leftcol">
                {local:facets()}
                </div>
                <div id="rightcol">
                    {local:display-results()}
                </div>
            </div>
        </div>
    </body>
</html>