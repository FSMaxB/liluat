return {
	code = [[coroutine.yield("<!DOCTYPE html>\
<html lang=\"en\">\
<head>\
    <meta charset=\"UTF-8\">\
    <title>")
coroutine.yield( title)
coroutine.yield("</title>\
</head>\
<body>\
    ")
coroutine.yield("<h1>This is the index page.</h1>\
")
coroutine.yield("\
    <ol>\
    ")
for i = 1, 5 do
coroutine.yield("\
        <li>")
coroutine.yield( i}</li>
    #{end)
coroutine.yield("\
    </ol>\
</body>\
</html>\
")]],
	name = "spec/index.html.template"
}