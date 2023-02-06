<?php
// NB: exit without printing anything in case of error

$utf8 = mb_convert_encoding(stream_get_contents(STDIN), 'HTML-ENTITIES', 'UTF-8'); // parse utf8 source correctly
$doc = new DomDocument();
@$doc->loadHTML($utf8) // silence bad html structure errors and warnings
    or exit;
$xpath = new DOMXpath($doc);
$href = $xpath->query('/html/body/main/ol/li[1]/a')?->item(0)?->attributes->getNamedItem('href')->textContent;
echo !!$href ? $href : '';
