---
---

requirejs.config({
    shim: {
        '../tools/kpack': {
            init: -> { FS: this.FS, Module: this.Module }
        },
        '../tools/genkfs': {
            init: -> { FS: this.FS, Module: this.Module }
        },
        '../tools/z80e': {
            init: -> { FS: this.FS, Module: this.Module }
        }
    }
})

window.toolchain = {
    kpack: null,
    genkfs: null,
    z80e: null,
    OpenTI: true, # TODO: Load OpenTI
    kernel_rom: null,
    kernel_inc: true # TODO: Add an assembler and load the kernel include into its filesystem
}

((el) ->
    # Set up default editors
    editor = ace.edit(el)
    editor.setTheme("ace/theme/github")
    if el.dataset.file.indexOf('.asm') == el.dataset.file.length - 4
        editor.getSession().setMode("ace/mode/assembly_x86")
)(el) for el in document.querySelectorAll('.editor')

log_el = document.getElementById('tool-log')
log = (text) ->
    console.log(text)
    if log_el.innerHTML == ''
        log_el.innerHTML += text
    else
        log_el.innerHTML += '\n' + text
    log_el.scrollTop = log_el.scrollHeight
window.ide_log = log

load_environment = ->
    toolchain.genkfs.FS.writeFile("/kernel.rom", toolchain.kernel_rom, { encoding: 'binary' })
    toolchain.genkfs.FS.mkdir("/model")
    toolchain.kpack.FS.mkdir("/pkg_root")

check_resources = ->
    for prop in Object.keys(window.toolchain)
        if window.toolchain[prop] == null
            return
    log("Ready to assemble.")
    load_environment()

downloadKernel = ->
    log("Finding latest kernel on GitHub...")
    xhr = new XMLHttpRequest()
    xhr.open('GET', 'https://api.github.com/repos/KnightOS/kernel/releases')
    xhr.onload = ->
        json = JSON.parse(xhr.responseText)
        release = json[0]
        log("Downloading kernel #{ release.tag_name }...")

        rom = new XMLHttpRequest()
        #rom.open('GET', _.find(release.assets, (a) -> a.name == 'kernel-TI84pSE.rom').browser_download_url) # TODO, pending support inquiry from GH
        rom.open('GET', 'http://irc.sircmpwn.com/kernel.rom')
        rom.responseType = 'arraybuffer'
        rom.onload = () ->
            window.toolchain.kernel_rom = rom.response
            log("Loaded kernel ROM.")
            check_resources()
        rom.send()

        inc = new XMLHttpRequest()
        #inc.open('GET', _.find(release.assets, (a) -> a.name == 'kernel.inc').browser_download_url) # TODO, pending support inquiry from GH
        inc.open('GET', 'http://irc.sircmpwn.com/kernel.inc')
        inc.onload = () ->
            # TODO: Add include to filesystem
            log("Loaded kernel headers.")
            check_resources()
        inc.send()
    xhr.send()

downloadKernel()

log("Downloading kpack...")
require(['../tools/kpack'], (kpack) ->
    log("Loaded kpack.")
    window.toolchain.kpack = kpack
    check_resources()
)

log("Downloading genkfs...")
require(['../tools/genkfs'], (genkfs) ->
    log("Loaded genkfs.")
    window.toolchain.genkfs = genkfs
    check_resources()
)

log("Downloading z80e...")
require(['../tools/z80e'], (z80e) ->
    log("Loaded z80e.")
    window.toolchain.z80e = z80e
    check_resources()
)
