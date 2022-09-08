xquery version "1.0-ml";

declare namespace http = "xdmp:http";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";
import module namespace search = "http://marklogic.com/appservices/search" at "/MarkLogic/appservices/search/search.xqy";

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

(: set of functions to organize and return query for search :)

declare function local:setQuery(){
    let $q := if(xdmp:get-request-field("query"))
            then xdmp:get-request-field("query")
            else ""
    let $s := if(xdmp:get-request-field("sortby"))
            then fn:concat("sort:", xdmp:get-request-field("sortby"))
            else ""
    let $f := local:join($q, local:addConstraints("Country"))
    let $f := local:join($f, local:addConstraints("Response")) 
    let $f := local:join($f, local:addConstraints("Domain")) 
    return fn:concat($f, " ", $s)
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
    return if(fn:empty($f)) then () else fn:string-join($f, " AND ")
};

(: set of function to get/set url to include correct/updated fields for query :)

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

declare function local:setPageURL($url, $p){
    let $currURL := if($url = "") then local:getURL() else $url
    let $currP := xdmp:get-request-field("page")
    let $newURL := fn:replace($currURL, fn:concat("page=", $currP), fn:concat("page=", $p))
    return $newURL
};

(: set of functions for displaying aspects of page :)

declare function local:display-results($results){
    let $docs := for $i in $results/search:result
                let $uri := fn:data($i/@uri)
                let $doc := fn:doc($uri)
                return $doc
    return if($docs)
            then (
                <div id="content">
                    <table cellspacing="0" width="700px">
                        <tr>
                            <th width="75px">ID</th>
                            <th width="325px">Title</th>
                            <th width="150px"><a href="{local:setPageURL(local:setURL("date"), 1)}" class="button">Date</a></th>
                            <th width="100px"><a href="{local:setPageURL(local:setURL("countryCode"), 1)}" class="button">Country Code</a></th>
                            <th width="75px">Response</th>
                        </tr>

                        {for $doc in $docs
                        let $id := $doc//GLOBALEVENTID
                        let $responseCode := if($doc//responseCode) then $doc//responseCode else "failed"
                        let $title := $doc//xhtml:html/xhtml:head/xhtml:title[1]/string()
                        let $title := if(fn:empty($title) or $title = "" or $responseCode = 403) then $doc//domain/string() else $title
                        let $title := if(fn:string-length($title) > 40) then fn:concat(fn:substring($title, 1, 40), "...") else $title
                        let $link := $doc//SOURCEURL
                        let $formatted-date := $doc//formatted-date
                        let $countryCode := $doc//countryCode
                        return( <tr>
                                    <td colspan="10"><hr/></td>
                                </tr>,

                                <tr>
                                    <td width="75px"><b>{$id}</b></td>
                                    <td width="325px"><a inlineSize="300px" href="{$link}">{$title}</a></td>
                                    <td width="150px"><b>{$formatted-date}</b></td>
                                    <td width="100px"><b>{$countryCode}</b></td>
                                    <td width="75px"><b>{$responseCode}</b></td>
                                </tr>
                        )}
                    </table>
                </div>
            )
            else <div>Sorry, no results for your search.<br/><br/><br/></div>
};

declare function local:facets($results){
    for $facet in $results/search:facet
    let $facet-count := fn:count($facet/search:facet-value)
    let $facet-name := fn:data($facet/@name)
    return  <div>
                <h3>{$facet-name}</h3>
                {
                    for $option in $facet/search:facet-value
                    let $option-name := $option/@name
                    return <div id="facet"><a href="{local:setPageURL(local:addFacetsURL($facet-name, $option-name), 1)}">{fn:data($option/@name)}</a><a> [{fn:data($option/@count)}]</a></div>
                }
            </div>
};

declare function local:displayPagination($page, $total){
    let $p := if($page)
                then $page
                else 0
    let $pages := xs:int($total div 20) + 1
    let $a := if($p > 5) then $p - 5 else 1
    let $b := if($p > 2) then if($page = $pages) then $p - 2 else $p - 1 else 1
    let $c := if($p > 2) then if($page = $pages) then $p - 1 else $p else 2
    let $d := if($p > 2) then if($page = $pages) then $p else $p + 1 else 3
    let $e := if($p < $pages - 5) then $p + 5 else $pages

    return (
        <div>
            <a href="{local:setPageURL("", 1)}"><img src="/images/startarrowblue.png"/></a>&nbsp;
            <a href="{local:setPageURL("", $a)}"><img src="/images/prevarrowblue.png"/></a>&nbsp;
            <a class="{local:pageIdentifier($page, $b)}" href="{local:setPageURL("", $b)}">{$b}</a>&nbsp;
            <a class="{local:pageIdentifier($page, $c)}" href="{local:setPageURL("", $c)}">{$c}</a>&nbsp;
            <a class="{local:pageIdentifier($page, $d)}" href="{local:setPageURL("", $d)}">{$d}</a>&nbsp;
            <a href="{local:setPageURL("", $e)}"><img src="/images/nextarrowblue.png"/></a>&nbsp;
            <a href="{local:setPageURL("", $pages)}"><img src="/images/endarrowblue.png"/></a>&nbsp;
        </div>
    )
};

declare function local:pageIdentifier($page, $p){
    let $select := if($page = $p) then "currPage" else "pageLink"
    return $select
};

xdmp:set-response-content-type("text/html; charset=utf-8"),
let $total := fn:count(fn:doc())
let $query := local:setQuery()
let $page := if(xdmp:get-request-field("page"))
                then xs:int(xdmp:get-request-field("page"))
                else 1
let $start := if($page)
                then (($page - 1) * 20) + 1
                else 1
let $results := search:search($query, $options, $start, 20)
let $resultTotal := fn:data($results/@total)
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
            </div>
            <div id="input">
                <form id="sinput" onsubmit="{local:getURL()}">
                    <input type="text" name="query" id="query" size="55" onsubmit="{local:getURL()}" value="{xdmp:get-request-field("query")}"/><button type="button" id="reset_button" onclick="document.location.href='index.xqy'">x</button>&#160;
                    <button type="submit" onsubmit="{local:getURL()}" href="{local:getURL()}">search</button>
                </form>
                <div id="pinput">
                    {local:displayPagination($page, $resultTotal)}
                </div>
            </div>
            <div id="display">
                <div id="leftcol">
                {local:facets($results)}
                </div>
                <div id="rightcol">
                    {local:display-results($results)}
                </div>
            </div>
        </div>
    </body>
</html>