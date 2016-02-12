return {
	code = [[
coroutine.yield("<!DOCTYPE html>\
<html lang=\"en\">\
<head>\
    <meta charset=\"UTF-8\">\
    <title>")
coroutine.yield( title)
coroutine.yield("</title>\
</head>\
<body>\
    <h1>This is the index page.</h1>\
\
    <ol>\
")
for i = 1, 5 do
coroutine.yield("        <li>")
coroutine.yield( i)
coroutine.yield("</li>\
")
end
coroutine.yield("    </ol>\
</body>\
</html>\
")]],
	name = "spec/index.html.template"
}
