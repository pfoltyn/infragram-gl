# This file is part of infragram-gl.
#
# infragram-gl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# infragram-gl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with infragram-gl.  If not, see <http://www.gnu.org/licenses/>.


img_context = null
map_context = null


initBuffers = (ctx) ->
    gl = ctx.gl
    ctx.vertexBuffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, ctx.vertexBuffer)
    vertices = [
       -1.0, -1.0,
        1.0, -1.0,
       -1.0,  1.0,
       -1.0,  1.0,
        1.0, -1.0,
        1.0,  1.0,]
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW)
    ctx.vertexBuffer.itemSize = 2

    ctx.textureBuffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, ctx.textureBuffer)
    textureCoords = [
        0.0,  0.0,
        1.0,  0.0,
        0.0,  1.0,
        0.0,  1.0,
        1.0,  0.0,
        1.0,  1.0]
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(textureCoords), gl.STATIC_DRAW)
    ctx.textureBuffer.itemSize = 2


createContext = (mode, greyscale, colormap, slider, canvasName) ->
    ctx = new Object()
    ctx.mode = mode
    ctx.greyscale = greyscale
    ctx.colormap = colormap
    ctx.slider = slider
    ctx.canvas = document.getElementById(canvasName)
    ctx.gl = getWebGLContext(ctx.canvas)
    initBuffers(ctx)
    return ctx


initShaders = (ctx) ->
    gl = ctx.gl
    ctx.shaderProgram = createProgramFromScripts(gl, ["shader-vs", "shader-fs"])
    gl.useProgram(ctx.shaderProgram)
    ctx.shaderProgram.vertexPositionAttribute = gl.getAttribLocation(ctx.shaderProgram, "aVertexPosition")
    gl.enableVertexAttribArray(ctx.shaderProgram.vertexPositionAttribute)
    ctx.shaderProgram.textureCoordAttribute = gl.getAttribLocation(ctx.shaderProgram, "aTextureCoord")
    gl.enableVertexAttribArray(ctx.shaderProgram.textureCoordAttribute)


drawScene = (ctx, returnImage) ->
    gl = ctx.gl
    gl.bindBuffer(gl.ARRAY_BUFFER, ctx.vertexBuffer)
    gl.vertexAttribPointer(ctx.shaderProgram.vertexPositionAttribute, ctx.vertexBuffer.itemSize, gl.FLOAT, false, 0, 0)

    gl.bindBuffer(gl.ARRAY_BUFFER, ctx.textureBuffer)
    gl.vertexAttribPointer(ctx.shaderProgram.textureCoordAttribute, ctx.textureBuffer.itemSize, gl.FLOAT, false, 0, 0)

    pSliderUniform = gl.getUniformLocation(ctx.shaderProgram, "uSlider")
    gl.uniform1f(pSliderUniform, ctx.slider)
    pNdviUniform = gl.getUniformLocation(ctx.shaderProgram, "uNdvi")
    gl.uniform1f(pNdviUniform, (if ctx.mode == "ndvi" then 1.0 else 0.0))
    pGreyscaleUniform = gl.getUniformLocation(ctx.shaderProgram, "uGreyscale")
    gl.uniform1f(pGreyscaleUniform, (if ctx.greyscale then 1.0 else 0.0))
    pHsvUniform = gl.getUniformLocation(ctx.shaderProgram, "uHsv")
    gl.uniform1f(pHsvUniform, (if ctx.mode == "hsv" then 1.0 else 0.0))
    pColormap = gl.getUniformLocation(ctx.shaderProgram, "uColormap")
    gl.uniform1f(pColormap, (if ctx.colormap then 1.0 else 0.0))

    gl.drawArrays(gl.TRIANGLES, 0, 6)

    if returnImage
        return ctx.canvas.toDataURL("image/png")


generateShader = (ctx, r, g, b) ->
    # Map HSV to shader variable names
    r = r.toLowerCase().replace(/h/g, "r").replace(/s/g, "g").replace(/v/g, "b")
    g = g.toLowerCase().replace(/h/g, "r").replace(/s/g, "g").replace(/v/g, "b")
    b = b.toLowerCase().replace(/h/g, "r").replace(/s/g, "g").replace(/v/g, "b")

    # Sanitize strings
    r = r.replace(/[^xrgb\/\-\+\*\(\)\.0-9]*/g, "")
    g = g.replace(/[^xrgb\/\-\+\*\(\)\.0-9]*/g, "")
    b = b.replace(/[^xrgb\/\-\+\*\(\)\.0-9]*/g, "")

    # Convert int to float
    r = r.replace(/([0-9])([^\.])?/g, "$1.0$2")
    g = g.replace(/([0-9])([^\.])?/g, "$1.0$2")
    b = b.replace(/([0-9])([^\.])?/g, "$1.0$2")

    r = "r" if r == ""
    g = "g" if g == ""
    b = "b" if b == ""

    code = $("#shader-fs-template").html()
    code = code.replace(/@1@/g, r)
    code = code.replace(/@2@/g, g)
    code = code.replace(/@3@/g, b)
    $("#shader-fs").html(code)

    initShaders(ctx)


download = (ctx) ->
    # create an "off-screen" anchor tag
    lnk = document.createElement("a")
    # the key here is to set the download attribute of the a tag
    lnk.download = (new Date()).toISOString().replace(":", "_") + ".png"
    lnk.href = drawScene(ctx, true)

    # create a "fake" click-event to trigger the download
    if document.createEvent
        event = document.createEvent("MouseEvents")
        event.initMouseEvent(
            "click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null)
        lnk.dispatchEvent(event)
    else if lnk.fireEvent
        lnk.fireEvent("onclick")


setMode = (ctx, newMode) ->
    ctx.mode = newMode
    $("#download").show()
    if ctx.mode == "ndvi"
        $("#colorbar-container")[0].style.display = "inline-block"
        $("#colormaps-group")[0].style.display = "inline-block"
    else
        $("#colorbar-container")[0].style.display = "none"
        $("#colormaps-group")[0].style.display = "none"


handleLoadedTexture = (ctx) ->
    gl = ctx.gl
    gl.activeTexture(gl.TEXTURE0)
    gl.bindTexture(gl.TEXTURE_2D, ctx.texture)
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, ctx.image)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    setMode(ctx, "raw");
    generateShader(ctx, "r", "g", "b")
    drawScene(ctx)


initTexture = (ctx, fileObject) ->
    ctx.texture = ctx.gl.createTexture()
    ctx.image = new Image()
    ctx.image.onload = () ->
        handleLoadedTexture(ctx)
    ctx.image.src = fileObject


$(window).load(() ->
    $("#shader-vs").load("shader.vert")
    $("#shader-fs-template").load("shader.frag")

    img_context = createContext("raw", true, false, 1.0, "canvas-image")
    map_context = createContext("ndvi", true, true, 1.0, "colorbar")
)


$(document).ready(() ->
    $("#file-sel").change(() ->
        if this.files && this.files[0]
            reader = new FileReader()
            reader.onload = (eventObject) ->
                initTexture(img_context, eventObject.target.result)
                generateShader(map_context, "r", "g", "b")
            reader.readAsDataURL(this.files[0])
    )

    $('button#raw').click(() ->
        setMode(img_context, "raw")
        generateShader(img_context, "r", "g", "b")
        drawScene(img_context)
    )

    $('button#ndvi').click(() ->
        setMode(img_context, "ndvi")
        generateShader(img_context, "(((r-b)/(r+b))+1)/2", "(((r-b)/(r+b))+1)/2", "(((r-b)/(r+b))+1)/2")
        drawScene(img_context)

        drawScene(map_context)
    )

    $('button#nir').click(() ->
        setMode(img_context, "nir")
        generateShader(img_context, "r", "r", "r")
        drawScene(img_context)
    )

    $('#download').click(() ->
        download(img_context)
    )

    $('#infragrammar_hsv').submit(() ->
        setMode(img_context, "hsv")
        generateShader(img_context, $('#h_exp').val(), $('#s_exp').val(), $('#v_exp').val())
        drawScene(img_context)
    )

    $('#infragrammar').submit(() ->
        setMode(img_context, "rgb")
        generateShader(img_context, $('#r_exp').val(), $('#g_exp').val(), $('#b_exp').val())
        drawScene(img_context)
    )

    $('#infragrammar_mono').submit(() ->
        setMode(img_context, "mono")
        generateShader(img_context, $('#m_exp').val(), $('#m_exp').val(), $('#m_exp').val())
        drawScene(img_context)
    )

    $('button#grey').click(() ->
        img_context.greyscale = true
        drawScene(img_context)

        map_context.greyscale = true
        drawScene(map_context)
    )

    $('button#color').click(() ->
        img_context.greyscale = false
        drawScene(img_context)

        map_context.greyscale = false
        drawScene(map_context)
    )

    # http://www.eyecon.ro/bootstrap-slider/
    $('#slider').slider().on('slide', (event) ->
        img_context.slider = event.value / 100.0
        drawScene(img_context)
    )
)
