package ysyx

object BazelElaborate extends App {
  val firtoolOptions = Array(
    "--disable-annotation-unknown",
    "--strip-debug-info",
  )

  circt.stage.ChiselStage.emitSystemVerilogFile(new ysyxSoCTop, args, firtoolOptions)
}
