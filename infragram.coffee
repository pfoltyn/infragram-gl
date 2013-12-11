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
slider = 1.0


initShaders = () ->
    shaderProgram = createProgramFromScripts(gl, ["shader-vs", "shader-fs"])
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
    drawScene()


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
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer)
    gl.vertexAttribPointer(shaderProgram.vertexPositionAttribute, vertexBuffer.itemSize, gl.FLOAT, false, 0, 0)

    gl.bindBuffer(gl.ARRAY_BUFFER, textureBuffer)
    gl.vertexAttribPointer(shaderProgram.textureCoordAttribute, textureBuffer.itemSize, gl.FLOAT, false, 0, 0)

    pSliderUniform = gl.getUniformLocation(shaderProgram, "uSlider")
    gl.uniform1f(pSliderUniform, slider)
    pNdviUniform = gl.getUniformLocation(shaderProgram, "uNdvi")
    gl.uniform1f(pNdviUniform, (if mode == "ndvi" then 1.0 else 0.0))
    pGreyscaleUniform = gl.getUniformLocation(shaderProgram, "uGreyscale")
    gl.uniform1f(pGreyscaleUniform, (if greyscale then 1.0 else 0.0))
    pHsvUniform = gl.getUniformLocation(shaderProgram, "uHsv")
    gl.uniform1f(pHsvUniform, (if mode == "hsv" then 1.0 else 0.0))

    gl.activeTexture(gl.TEXTURE0)
    gl.bindTexture(gl.TEXTURE_2D, texture)

    gl.drawArrays(gl.TRIANGLES, 0, 6)

    if returnImage
        return canvas.toDataURL("image/png")


generateShader = (r, g, b) ->
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

    if r == ""
        r = "r"
    if g == ""
        g = "g"
    if b == ""
        b = "b"
    
    document.getElementById("shader-fs").text = "
        precision mediump float;
        varying vec2 vTextureCoord;
        uniform sampler2D uSampler;
        uniform float uSlider;
        uniform float uNdvi;
        uniform float uGreyscale;
        uniform float uHsv;

        vec4 greyscale_colormap(float n)
        {
            vec3 x  = vec3(0.0, 1.0, 0.0);
            vec3 y0 = vec3(0.0, 0.0, 0.0);
            vec3 y1 = vec3(255.0, 255.0, 255.0) / 255.0;

            return vec4(
                (n - x[0]) / (x[1] - x[0]) * (y1[0] - y0[0]) + y0[0],
                (n - x[0]) / (x[1] - x[0]) * (y1[1] - y0[1]) + y0[1],
                (n - x[0]) / (x[1] - x[0]) * (y1[2] - y0[2]) + y0[2],
                1.0);
        }

        vec4 color_colormap(float n)
        {
            vec3 x = vec3(0.0, 0.5, 0.0);
            vec3 y0 = vec3(25.0, 0.0, 175.0) / 255.0;
            vec3 y1 = vec3(38.0, 195.0, 195.0) / 255.0;

            if (n >= 0.5)
            {
                x = vec3(0.5, 0.75, 0.0);
                y0 = vec3(50.0, 155.0, 60.0) / 255.0;
                y1 = vec3(195.0, 190.0, 90.0) / 255.0;
            }
            else if (n >= 0.75)
            {
                x = vec3(0.75, 1.0, 0.0);
                y0 = vec3(195.0, 190.0, 90.0) / 255.0;
                y1 = vec3(185.0, 50.0, 50.0) / 255.0;
            }

            return vec4(
                (n - x[0]) / (x[1] - x[0]) * (y1[0] - y0[0]) + y0[0],
                (n - x[0]) / (x[1] - x[0]) * (y1[1] - y0[1]) + y0[1],
                (n - x[0]) / (x[1] - x[0]) * (y1[2] - y0[2]) + y0[2],
                1.0);
        }

        vec4 rgb2hsv(vec4 c)
        {
            vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
            vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

            float d = q.x - min(q.w, q.y);
            float e = 1.0e-10;
            return vec4(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x, 1.0);
        }

        vec4 hsv2rgb(vec4 c)
        {
            vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
            return vec4(c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y), 1.0);
        }

        void main(void)
        {
            vec4 color = texture2D(uSampler, vTextureCoord);
            if (uHsv >= 1.0)
            {
                color = rgb2hsv(color);
            }
            float x = uSlider;
            float r = color.r;
            float g = color.g;
            float b = color.b;" +
           "float rr = " + r + ";" +
           "float gg = " + g + ";" +
           "float bb = " + b + ";" +
           "if (uNdvi < 1.0)
            {
                color = vec4(rr, gg, bb, 1.0);
                gl_FragColor = (uHsv < 1.0) ? color : hsv2rgb(color);
            }
            else
            {
                gl_FragColor = (uGreyscale < 1.0) ? color_colormap(rr) : greyscale_colormap(rr);
            }
        }"

    initShaders()


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
    $("#download").show()


setSlider = (value) ->
    slider = value


setMode = (newMode) ->
    mode = newMode
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
            generateShader("r", "g", "b")
            initShaders()
            initTexture(e.target.result)
            $("#download").show()
        reader.readAsDataURL(input.files[0])
