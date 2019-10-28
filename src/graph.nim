import strutils

proc getGraph*(x,y: string): string =
    var html = """
    <html>
        <head>
            <script 
                src="https://cdn.plot.ly/plotly-latest.min.js">
            </script>
        </head>
        <body>
            <div id="graph"></div>
            <script>
                GR = document.getElementById('graph');
                Plotly.plot( GR, [
                    {
                        x: $#,
                        y: $# 
                    }], 
                {margin: { t: 0 } } );
            </script>
        </body>
    </html>""" % [x, y]
    return html