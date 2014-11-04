---
---

require.config({
    paths: {
        'z80e': '../tools/z80e'
    },
    shim: {
        '../tools/kpack': {
            exports: 'exports'
        },
        '../tools/genkfs': {
            exports: 'exports'
        },
        'z80e': {
            exports: 'exports'
        }
    }
})

window.toolchain = {
    kpack: null,
    genkfs: null,
    z80e: null,
    ide_emu: null
    kernel_rom: null,
    kernel_inc: true # TODO: Add an assembler and load the kernel include into its filesystem
}

log_el = document.getElementById('tool-log')
log = (text) ->
    console.log(text)
    if log_el.innerHTML == ''
        log_el.innerHTML += text
    else
        log_el.innerHTML += '\n' + text
    log_el.scrollTop = log_el.scrollHeight
window.ide_log = log

# Load remote resources

current_emulator = null

load_environment = ->
    toolchain.genkfs.FS.writeFile("/kernel.rom", toolchain.kernel_rom, { encoding: 'binary' })
    toolchain.genkfs.FS.mkdir("/model")
    toolchain.kpack.FS.mkdir("/pkg_root")
    current_emulator = new toolchain.ide_emu(document.getElementById('screen').getContext('2d'))
    current_emulator.load_rom(toolchain.kernel_rom)

check_resources = ->
    for prop in Object.keys(window.toolchain)
        if window.toolchain[prop] == null
            return
    log("Ready.")
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

log("Downloading emulator bindings...")
require(['ide_emu'], (ide_emu) ->
    log("Loaded emulator bindings.")
    window.toolchain.ide_emu = ide_emu
    window.toolchain.z80e = require("z80e")
    check_resources()
)

# Bind stuff to the UI

document.getElementById('run-project').addEventListener('click', (e) ->
    run_project()
)

((el) ->
    # Set up default editors
    editor = ace.edit(el)
    editor.setTheme("ace/theme/github")
    if el.dataset.file.indexOf('.asm') == el.dataset.file.length - 4
        editor.getSession().setMode("ace/mode/assembly_x86")
)(el) for el in document.querySelectorAll('.editor')
