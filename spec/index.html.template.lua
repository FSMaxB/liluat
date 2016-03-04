return {
	code = [[
__liluat_output_function("<!DOCTYPE html>\
<html lang=\"en\">\
<head>\
    <meta charset=\"UTF-8\">\
    <title>")
__liluat_output_function( title)
__liluat_output_function("</title>\
</head>\
<body>\
    <h1>This is the index page.</h1>\
\
    <ol>\
")
for i = 1, 5 do
__liluat_output_function("        <li>")
__liluat_output_function( i)
__liluat_output_function("</li>\
")
end
__liluat_output_function("    </ol>\
</body>\
</html>\
")]],
	name = "spec/index.html.template"
}
