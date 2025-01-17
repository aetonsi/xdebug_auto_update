<?php
// NB: exit without printing anything in case of error

// $utf8 = mb_convert_encoding(stream_get_contents(STDIN), 'HTML-ENTITIES', 'UTF-8'); // parse utf8 source correctly
// $utf8 = \htmlentities($in, ENT_HTML5, 'UTF-8'); // parse utf8 source correctly

libxml_use_internal_errors(true);
$in = stream_get_contents(STDIN);
$doc = \Dom\HTMLDocument::createFromString($in, LIBXML_NOERROR|LIBXML_COMPACT|LIBXML_HTML_NOIMPLIED|Dom\HTML_NO_DEFAULT_NS) // silence bad html structure errors and warnings
    or exit(33);
$href = $doc?->querySelector('html body main ol li:first-child a')?->getAttribute('href');

echo !!$href ? $href : '';
