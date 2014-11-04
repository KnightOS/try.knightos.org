define(['../OpenTI/webui/js/OpenTI/OpenTI'], function(OpenTI) {
    return function(canvas) {
        asic = new OpenTI.TI.ASIC(OpenTI.TI.DeviceType.TI84pSE);
        asic.debugger = new OpenTI.Debugger.Debugger(asic);
        this.asic = asic;
    }
})
