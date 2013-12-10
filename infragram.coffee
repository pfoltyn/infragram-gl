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


canvas = null
gl = null
shaderProgram = null
vertexBuffer = null
textureBuffer = null
texture = null

mode = "raw"
greyscale = true
slider = 0.0


initShaders = (shaderNames) ->
    shaderProgram = createProgramFromScripts(gl, shaderNames)
    gl.useProgram(shaderProgram)
    shaderProgram.vertexPositionAttribute = gl.getAttribLocation(shaderProgram, "aVertexPosition")
    gl.enableVertexAttribArray(shaderProgram.vertexPositionAttribute)
    shaderProgram.textureCoordAttribute = gl.getAttribLocation(shaderProgram, "aTextureCoord")
    gl.enableVertexAttribArray(shaderProgram.textureCoordAttribute)


initBuffers = () ->
    vertexBuffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer)
    vertices = [
       -1.0, -1.0,
        1.0, -1.0,
       -1.0,  1.0,
       -1.0,  1.0,
        1.0, -1.0,
        1.0,  1.0,]
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW)
    vertexBuffer.itemSize = 2

    textureBuffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, textureBuffer)
    textureCoords = [
        0.0,  0.0,
        1.0,  0.0,
        0.0,  1.0,
        0.0,  1.0,
        1.0,  0.0,
        1.0,  1.0]
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(textureCoords), gl.STATIC_DRAW)
    textureBuffer.itemSize = 2


handleLoadedTexture = (texture) ->
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true)
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, texture.image)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.bindTexture(gl.TEXTURE_2D, null)
    drawScene(false)


initTexture = (fileObject) ->
    texture = gl.createTexture()
    if !texture
        alert("Failed to create square buffer")

    if texture
        texture.image = new Image()
        if !texture.image
            alert("Failed to create image")

    if texture and texture.image
        texture.image.onload = () ->
            handleLoadedTexture(texture)
        texture.image.src = fileObject


drawScene = (returnImage) ->
    #requestAnimFrame(drawScene, canvas)

    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer)
    gl.vertexAttribPointer(shaderProgram.vertexPositionAttribute, vertexBuffer.itemSize, gl.FLOAT, false, 0, 0)

    gl.bindBuffer(gl.ARRAY_BUFFER, textureBuffer)
    gl.vertexAttribPointer(shaderProgram.textureCoordAttribute, textureBuffer.itemSize, gl.FLOAT, false, 0, 0)

    if mode == "infragrammar"
        pSliderUniform = gl.getUniformLocation(shaderProgram, "uSlider")
        gl.uniform1f(pSliderUniform, slider)
    else
        pModeUniform = gl.getUniformLocation(shaderProgram, "uMode")
        switch mode
            when "ndvi" then gl.uniform1f(pModeUniform, 1.0)
            when "nir" then gl.uniform1f(pModeUniform, 2.0)
            else gl.uniform1f(pModeUniform, 0.0)

        pGreyscaleUniform = gl.getUniformLocation(shaderProgram, "uGreyscale")
        if greyscale
            gl.uniform1f(pGreyscaleUniform, 1.0)
        else
            gl.uniform1f(pGreyscaleUniform, 0.0)

    gl.activeTexture(gl.TEXTURE0)
    gl.bindTexture(gl.TEXTURE_2D, texture)

    gl.drawArrays(gl.TRIANGLES, 0, 6)

    if returnImage
        return canvas.toDataURL("image/png")


generateShader = (r, g, b) ->
    # Sanitize strings
    r = r.toLowerCase().replace(/[^srgb\/\-\+\*\(\)\.0-9]*/g, "")
    g = g.toLowerCase().replace(/[^srgb\/\-\+\*\(\)\.0-9]*/g, "")
    b = b.toLowerCase().replace(/[^srgb\/\-\+\*\(\)\.0-9]*/g, "")

    # Convert int to float
    r = r.replace(/([0-9])([^\.])?/g, "$1.0$2")
    g = g.replace(/([0-9])([^\.])?/g, "$1.0$2")
    b = b.replace(/([0-9])([^\.])?/g, "$1.0$2")

    document.getElementById("generated-shader-fs").text = "
        precision mediump float;
        varying vec2 vTextureCoord;
        uniform sampler2D uSampler;
        uniform float uSlider;

        void main(void)
        {
            vec4 color = texture2D(uSampler, vTextureCoord);
            float s = uSlider;
            float r = color.r;
            float g = color.g;
            float b = color.b;" +
           "float rr = " + r + ";" +
           "float gg = " + g + ";" +
           "float bb = " + b + ";" +
           "gl_FragColor = vec4(rr, gg, bb, 1.0);
        }"


webGlStart = () ->
    canvas = document.getElementById("canvas-image")
    gl = getWebGLContext(canvas)
    initBuffers()


download = () ->
    # create an "off-screen" anchor tag
    lnk = document.createElement("a")
    # the key here is to set the download attribute of the a tag
    lnk.download = (new Date()).toISOString().replace(":", "_") + ".png"
    lnk.href = drawScene(true)

    # create a "fake" click-event to trigger the download
    if document.createEvent
        event = document.createEvent("MouseEvents")
        event.initMouseEvent(
            "click", true, true, window, 0, 0, 0, 0, 0, false, false, false, false, 0, null)
        lnk.dispatchEvent(event)
    else if lnk.fireEvent
        lnk.fireEvent("onclick")


setGreyscale = (value) ->
    greyscale = value
    drawScene(false)
    $("#download").show()


setSlider = (value) ->
    slider = value
    drawScene(false)


setMode = (newMode) ->
    mode = newMode
    if mode == "infragrammar"
        initShaders(["shader-vs", "generated-shader-fs"])
    else
        initShaders(["shader-vs", "shader-fs"])
    drawScene(false)

    $("#download").show()
    if mode == "ndvi"
        $("#colormaps-group")[0].style.display = "inline-block"
    else
        $("#colormaps-group")[0].style.display = "none"


onFileSelect = () ->
    input = document.getElementById("file-sel")
    if input.files && input.files[0]
        reader = new FileReader()
        reader.onload = (e) ->
            initShaders(["shader-vs", "shader-fs"])
            initTexture(e.target.result)
            $("#download").show()
        reader.readAsDataURL(input.files[0])
