package ysyx

object BazelElaborate extends App {
  val firtoolOptions = Array(
    "--disable-annotation-unknown",
  )

  circt.stage.ChiselStage.emitSystemVerilogFile(new ysyxSoCTop, args, firtoolOptions)
}
