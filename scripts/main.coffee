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

tree_data = undefined

json2html = (json) ->
  i = undefined
  ret = document.createElement('ul')
  li = undefined
  for i of json
    `i = i`
    li = ret.appendChild(document.createElement('li'))
    li.appendChild document.createTextNode(i + ': ')
    if typeof json[i] == 'object'
      li.appendChild json2html(json[i])
    else
      li.firstChild.nodeValue += json[i]
  ret

$.ajax
  type: 'GET'
  url: 'http://www.knightos.org/documentation/reference/data.json'
  async: true
  beforeSend: (x) ->
    if x and x.overrideMimeType
      x.overrideMimeType 'application/j-son;charset=UTF-8'
    return
  dataType: 'json'
  success: (data, textStatus, jqXHR) ->
    tree_data_temp = jqXHR.responseText
    tree_data = JSON.parse(tree_data_temp)
    $('.doc-body').append json2html(tree_data)
    $ ->
      $('.doc-body').jstree 'plugins': [
        'search'
        'sort'
      ]
      to = false
      $('.doc_search').keyup ->
        if to
          clearTimeout to
        to = setTimeout((->
          v = $('.doc_search').val()
          $('.doc-body').jstree(true).search v
          return
        ), 250)
        return
      return
    return


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
    $("[data-package='#{full_name}']").attr('disabled','disabled').text('Installing')
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
        $("[data-package='#{full_name}']").text('Installed')
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
            run_project()
    install_package('core', 'init', callback)
    install_package('core', 'kernel-headers', callback)
    install_package('core', 'corelib', callback)

    for file in files
        saved = localStorage.getItem file.name
        if(saved != null)
            file.editor.setValue(saved, 1)

run_project = ->
    # Clear all Ace Annotations
    $('#run-project').removeAttr('disabled')
    _.each(files, (el) ->
       el.editor.getSession().clearAnnotations()
    );

    # Assemble
    for file in files
        window.toolchain.scas.FS.writeFile('/' + file.name, file.editor.getValue())
        localStorage.setItem file.name, file.editor.getValue()

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
    log("Downloading latest kernel...")
    xhr = new XMLHttpRequest()
    xhr.open('GET', 'http://builds.knightos.org/latest-TI84pSE.rom')
    xhr.setRequestHeader("Accept", "application/octet-stream")
    xhr.responseType = 'arraybuffer'
    xhr.onload = ->
        window.toolchain.kernel_rom = xhr.response
        log("Loaded kernel ROM.")
        check_resources()
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
    pack = $(this).data('package').split('/')
    install_package(pack[0], pack[1])
)

$('.load-exmaple').on('click', (e) ->
    e.preventDefault()
    xhr = new XMLHttpRequest();
    xhr.open('GET', $(this).data('source'));
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
    if not id || _.some(files, {name: id + ".asm"})
        return

    $('.tab-content').append("<div class='tab-pane' id='#{ id }'><div class='editor' data-file='#{ id }.asm'></div></div>")
    $('.nav.nav-tabs').append("<li><a data-toggle='tab' href='##{ id }'>#{ id }.asm</a></li>")

    el = document.querySelector("##{ id }>div")
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

showSettingsMenu = () ->
    for file in files
        file.editor.execCommand("showSettingsMenu")


$('#settings').on('click',(e) ->
  e.preventDefault()
  showSettingsMenu()
  return
)

getSelectedText = ->
  text = ''
  if window.getSelection
    text = window.getSelection().toString()
  else if document.selection and document.selection.type != 'Control'
    text = document.selection.createRange().text
  text

# ShortCuts
commands =
  new_file: () ->
      $('.modal').modal('hide')
      $('#new_file_Modal').modal('show')
      $('#new_file_title').focus()
  shortcut: () ->
      $('.modal').modal('hide')
      $('#shortcut_Modal').modal('show')
  settings: () ->
      showSettingsMenu()
  docs: () ->
      $('.modal').modal('hide')
      $('#docs_Modal').modal('show')
  search: () ->
      $('.modal').modal('hide')
      $('#docs_Modal').modal('show')
      for file in files
          if(file.editor.getSelectedText())
             $('input.doc_search').val(file.editor.getSelectedText())
             break
          else
             break
      $('input.doc_search').focus()
      e = jQuery.Event( 'keydown', { which: 13 } )
      $('input.doc_search').trigger(e)


down_key = []
ctrlCut = []
altCut = []

ctrlCut[78] = commands.new_file
ctrlCut[82] = () -> run_project()
ctrlCut[186] = commands.search
ctrlCut[188] = commands.settings
ctrlCut[190] = commands.shortcut
ctrlCut[191] = commands.docs

window.on('keydown',(e) ->
    key = e.which
    if(down_key[key])
        return

    if(e.ctrlKey && ctrlCut[key]?)
        e.preventDefault();
        ctrlCut[key]()
    else if(e.altKey && altCut[key]?)
        e.preventDefault();
        altCut[key]()
    else if(key == 13 && $('.doc_search').is ':focus')
        e.stopPropagation();
        e.preventDefault();


    down_key[key] = true
)
window.on('keyup',(e) ->
    key = e.which
    delete down_key[key]
)

#thanks stackoverflow; for autosaving
(($) ->
  $.fn.extend donetyping: (callback, timeout) ->
    timeout = timeout or 1e3
    timeoutReference = undefined

    doneTyping = (el) ->
      if !timeoutReference
        return
      timeoutReference = null
      callback.call el
      return

    @each (i, el) ->
      $el = $(el)
      $el.is(':input') and $el.on('keyup keypress', (e) ->
        if e.type == 'keyup' and e.keyCode != 8
          return
        if timeoutReference
          clearTimeout timeoutReference
        timeoutReference = setTimeout((->
          doneTyping el
          return
        ), timeout)
        return
      ).on('blur', ->
        doneTyping el
        return
      )
      return
  return
) jQuery

$('.ace_text-input').donetyping ->
  for file in files
    localStorage.setItem file.name, file.editor.getValue()
    return
