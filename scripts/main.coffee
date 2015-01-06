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
        '../tools/scas': {
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
    scas: null,
    z80e: null,
    ide_emu: null,
    kernel_rom: null,
}

files = []

log_el = document.getElementById('tool-log')
log = (text) ->
    console.log(text)
    if log_el.innerHTML == ''
        log_el.innerHTML += text
    else
        log_el.innerHTML += '\n' + text
    log_el.scrollTop = log_el.scrollHeight
window.ide_log = log

error_log = []
error = (text) ->
    log(text)
    error_log.push(text)

window.ide_error = error

copy_between_systems = (fs1, fs2, from, to, encoding) ->
    for f in fs1.readdir(from)
        continue if f in ['.', '..']
        fs1p = from + '/' + f
        fs2p = to + '/' + f
        s = fs1.stat(fs1p)
        log("Writing #{fs1p} to #{fs2p}")
        if fs1.isDir(s.mode)
            try
                fs2.mkdir(fs2p)
            catch
                # pass
            copy_between_systems(fs1, fs2, fs1p, fs2p, encoding)
        else
            fs2.writeFile(fs2p, fs1.readFile(fs1p, { encoding: encoding }), { encoding: encoding })

install_package = (repo, name, callback) ->
    full_name = repo + '/' + name
    log("Downloading " + full_name)
    xhr = new XMLHttpRequest()
    xhr.open('GET', "https://packages.knightos.org/" + full_name + "/download")
    xhr.responseType = 'arraybuffer'
    xhr.onload = () ->
        log("Installing " + full_name)
        file_name = '/packages/' + repo + '-' + name + '.pkg'
        data = new Uint8Array(xhr.response)
        toolchain.kpack.FS.writeFile(file_name, data, { encoding: 'binary' })
        toolchain.kpack.Module.callMain(['-e', file_name, '/pkgroot'])
        copy_between_systems(toolchain.kpack.FS, toolchain.scas.FS, "/pkgroot/include", "/include", "utf8")
        copy_between_systems(toolchain.kpack.FS, toolchain.genkfs.FS, "/pkgroot", "/root", "binary")
        $("[data-package='#{full_name}']").attr('disabled','disabled').text('Installed')
        callback() if callback?
    xhr.send()

current_emulator = null

load_environment = ->
    toolchain.genkfs.FS.writeFile("/kernel.rom", toolchain.kernel_rom, { encoding: 'binary' })
    toolchain.genkfs.FS.mkdir("/root")
    toolchain.genkfs.FS.mkdir("/root/etc")
    toolchain.kpack.FS.mkdir("/packages")
    toolchain.kpack.FS.mkdir("/pkgroot")
    toolchain.kpack.FS.mkdir("/pkgroot/include")
    toolchain.scas.FS.mkdir("/include")
    packages = 0
    callback = () ->
        packages++
        if packages == 3
            setTimeout(() -> 
                run_project()
            , 1000)
    install_package('core', 'init', callback)
    install_package('core', 'kernel-headers', callback)
    install_package('core', 'corelib', callback)

run_project = ->
    # Clear all Ace Annotations
    $('#run-project').removeAttr('disabled')
    _.each(files, (el) ->
       el.editor.getSession().clearAnnotations()
    );

    # Assemble
    for file in files
        window.toolchain.scas.FS.writeFile('/' + file.name, file.editor.getValue())

    log("Calling assembler...")

    window.toolchain.scas.Module.callMain(['/main.asm', '-I/include/', '-o', 'executable'])
    error_annotations = {}
    for elog in error_log
        error_text = elog.split(':')
        if error_text.length < 5
            continue

        file = error_text[0]

        if elog.indexOf('/') == 0
            file = file.substring(1)
        file = _.find(files, (el) ->
            return el.name == file;
        );
        
        if not file
           return
            
        if not error_annotations[file.name]?
            error_annotations[file.name] = []

        error_annotations[file.name].push({
          row: error_text[1] - 1,
          column: error_text[2],
          text: error_text[4].substring(1),
          type: "error"
        })
        
    _.each(error_annotations, (value,key) ->
        _.find(files, {name:key}).editor.getSession().setAnnotations(value)
    )
    error_log = []

    if window.toolchain.scas.FS.analyzePath("/executable").exists
        log("Assembly done!")
    else
        log("Assembly failed");
        return;

    # Build filesystem
    executable = window.toolchain.scas.FS.readFile("/executable", { encoding: 'binary' })

    window.toolchain.genkfs.FS.writeFile("/root/bin/executable", executable, { encoding: 'binary' })
    window.toolchain.genkfs.FS.writeFile("/root/etc/inittab", "/bin/executable")
    window.toolchain.genkfs.FS.writeFile("/kernel.rom", new Uint8Array(toolchain.kernel_rom), { encoding: 'binary' })
    window.toolchain.genkfs.Module.callMain(["/kernel.rom", "/root"])
    rom = window.toolchain.genkfs.FS.readFile("/kernel.rom", { encoding: 'binary' })

    log("Loading your program into the emulator!")
    if current_emulator != null
        current_emulator.cleanup()
    current_emulator = new toolchain.ide_emu(document.getElementById('screen'))
    window.emu = current_emulator
    current_emulator.load_rom(rom.buffer)

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
        rom = new XMLHttpRequest()
        if release?
            log("Downloading kernel #{ release.tag_name }...")
            rom.open('GET', _.find(release.assets, (a) -> a.name == 'kernel-TI84pSE.rom').url)
        else
            # fallback
            log("Downloading kernel")
            rom.open('GET', 'http://builds.knightos.org/latest-TI84pSE.rom')
        rom.setRequestHeader("Accept", "application/octet-stream")
        rom.responseType = 'arraybuffer'
        rom.onload = () ->
            window.toolchain.kernel_rom = rom.response
            log("Loaded kernel ROM.")
            check_resources()
        rom.send()
    xhr.onerror = ->
    xhr.send()

downloadKernel()

log("Downloading scas...")
require(['../tools/scas'], (scas) ->
    log("Loaded scas.")
    window.toolchain.scas = scas
    window.toolchain.scas.Module.preRun.pop()()
    check_resources()
)

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
$("[data-package]").on('click', (e) ->
    e.preventDefault()
    pack = $(this).attr('data-package').split('/')
    install_package(pack[0], pack[1])
)

$('.load-exmaple').on('click', (e) ->
    e.preventDefault()
    xhr = new XMLHttpRequest();
    xhr.open('GET', $(this).attr('data-source'));
    xhr.onload = () ->
        files[0].editor.setValue(this.responseText)
        files[0].editor.navigateFileStart();
    xhr.send();
)


$('#run-project').on('click', (e) ->
    run_project()
)
$('#new_file').on('click',(e) ->
    e.preventDefault()
    id = $('#new_file_title').val();
    $('#new_file_title').val('');
    $('.tab-content').append("<div class='tab-pane' id='#{ id }'><div class='editor' data-file='#{ id }.asm'></div></div>")
    $('.nav.nav-tabs').append("<li><a data-toggle='tab' href='##{ id }'>#{ id }.asm</a></li>")

    el = document.querySelector("##{ id }>div")
    console.log(id)
    editor = ace.edit(el)
    editor.setTheme("ace/theme/github")
    if el.dataset.file.indexOf('.asm') == el.dataset.file.length - 4
        editor.getSession().setMode("ace/mode/assembly_x86")
    files.push({
        name: el.dataset.file,
        editor: editor
    })
    resizeAce()
)

((el) ->
    # Set up default editors
    editor = ace.edit(el)
    editor.setTheme("ace/theme/github")
    if el.dataset.file.indexOf('.asm') == el.dataset.file.length - 4
        editor.getSession().setMode("ace/mode/assembly_x86")
    files.push({
        name: el.dataset.file,
        editor: editor
    })
)(el) for el in document.querySelectorAll('.editor')

resizeAce = () ->
    $('.editor').css('height', (window.innerHeight - 92).toString() + 'px');
    for file in files
        file.editor.resize()
        
$(window).on('resize', () ->
    resizeAce()
)
resizeAce()
# ShourtCuts
commands =
  new_file: () ->
      $('.modal').modal('hide')
      $('#new_file_Modal').modal('show')
      $('#new_file_title').focus()
  shortcut: () -> 
      $('.modal').modal('hide')
      $('#shortcut_Modal').modal('show')

down_key = []
shiftCut = []
ctrlCut = []
altCut = []

ctrlCut[78] = commands.new_file
ctrlCut[82] = () -> run_project()
ctrlCut[190] = commands.shortcut

window.addEventListener('keydown',(e) ->
    key = e.which   
    if(down_key[key])
        return
        
    if(e.ctrlKey && ctrlCut[key]?)
        e.preventDefault();
        ctrlCut[key]()
         
    down_key[key] = true
)
window.addEventListener('keyup',(e) ->
    key = e.which
    delete down_key[key]
)