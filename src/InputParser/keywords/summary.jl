@keyword :SUMMARY (
    :NSTACK, :RPTSOL, :WMCTL, :RPTRST, :WLPR, :WGOR, :WWIR, :WWPR, :WOPR,
    :WBHP
) RecordKeyword support = :ignored

@keyword :SUMMARY (
    :EXCEL, :RUNSUM, :SEPARATE, :NEWTON, :TCPU, :ELAPSED, :MAXDPR, :FOPR, :FWPR,
    :FWIR, :FOPT, :FWPT, :FWIT, :RPTONLY
) FlagKeyword support = :ignored

@keyword :SUMMARY (:BGSAT, :BOSAT, :BOKR, :BWSAT, :BPR) RecordsKeyword support = :ignored

function finish_current_section!(data, units, cfg, outer_data, ::Val{:SUMMARY})

end
