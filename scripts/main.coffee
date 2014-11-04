---
---

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

temp = 0
check_resources = ->
    # Checks to see if we're ready to compile things
    temp++
    if temp == 2
        log("Ready to assemble.")

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
        rom.onload = () ->
            # TODO: Add kernel to filesystem
            log("Saved kernel-TI84pSE.rom to /res/kernel.rom")
            check_resources()
        rom.send()

        inc = new XMLHttpRequest()
        #inc.open('GET', _.find(release.assets, (a) -> a.name == 'kernel.inc').browser_download_url) # TODO, pending support inquiry from GH
        inc.open('GET', 'http://irc.sircmpwn.com/kernel.inc')
        inc.onload = () ->
            # TODO: Add kernel to filesystem
            log("Saved kernel.inc to /include/kernel.inc")
            check_resources()
        inc.send()
    xhr.send()

downloadKernel()
