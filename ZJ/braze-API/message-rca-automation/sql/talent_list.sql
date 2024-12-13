WITH talent_list AS
    (SELECT DISTINCT date_dt
                   , eligible_matched_talent
                   , user_uuid
                   , employment_city
                   , matching_region_name
                   , matched_tag
     FROM dwh_db.tmp.talent_eligibility_model tem
              LEFT JOIN dwh_db.cds.dim_talent dtn ON tem.eligible_matched_talent = dtn.talent_id
     WHERE date_dt = current_date)
   , worked_category AS
    (SELECT DISTINCT eligible_matched_talent
                   , USER_uuid
                   , djc.job_category_name                                                                        as working_preference
                   , max(shift_dt)
                     over (PARTITION BY eligible_matched_talent, job_category_name)                               AS max_shift_category
                   , rank()
                     over (PARTITION BY eligible_matched_talent, job_category_name ORDER BY shift_dt desc)        AS rnk_shifts
                   , count(shift_dt)
                     over (PARTITION BY eligible_matched_talent, job_category_name)                               AS working_count
                   , matched_tag
                   , max(shift_dt) over (PARTITION BY eligible_matched_talent)                                    AS last_booked_shift
     FROM talent_list tl
              JOIN dwh_db.cds.fact_shift FS ON tl.eligible_matched_talent = FS.booked_shift_talent_id
              JOIN dwh_db.cds.fact_job fj ON FS.job_fk = fj.job_id AND tl.matched_tag = fj.mandatory_include_tags
              JOIN dwh_db.cds.dim_job_category djc ON FS.job_category_fk = djc.job_category_id
     WHERE TRUE
     GROUP BY 1, 2, 3, shift_dt, 7
     QUALIFY max_shift_category = last_booked_shift
         AND rnk_shifts = 1
     ORDER BY 5 ASC)
   , last_applied_shift AS
    (SELECT DISTINCT eligible_matched_talent
                   , user_uuid
                   , rank() over (PARTITION BY talent_uuid ORDER BY "timestamp" desc)                                AS rnk_shifts
                   , count(job_category_name) over (PARTITION BY eligible_matched_talent)                            AS cnt_shifts
                   , count(jac.job_uuid)
                     OVER (PARTITION BY eligible_matched_talent, job_category_name, matched_tag)                     AS no_shifts_applied
                   , djc.job_category_name
                   , matched_tag
                   , max("timestamp") over (PARTITION BY eligible_matched_talent)                                    AS last_applied_job
     FROM talent_list tl
              LEFT JOIN dwh_db.dds.job_apply_core jac ON tl.user_uuid = jac.talent_uuid
              JOIN dwh_db.cds.fact_job fj ON jac.job_uuid = fj.job_uuid AND tl.matched_tag = fj.mandatory_include_tags
              JOIN dwh_db.cds.dim_job_category djc ON Fj.job_category_fk = djc.job_category_id
     WHERE TRUE
       AND timestamp >= dateadd('day', -60, current_date)
       AND timestamp <= dateadd('day', 1, current_date))
   , applied_preference as
    (SELECT DISTINCT eligible_matched_talent
                   , user_uuid
                   , cnt_shifts
                   , no_shifts_applied                                                                               as applied_count
                   , dense_rank()
                     OVER (PARTITION BY eligible_matched_talent ORDER BY no_shifts_applied desc)                     AS ranking_by_cnt
                   , CASE WHEN cnt_shifts = rnk_shifts THEN job_category_name END                                    AS applied_preference
                   , job_category_name
                   , matched_tag
                   , last_applied_job
                   , CASE
                         WHEN count(user_uuid) OVER (PARTITION BY eligible_matched_talent) = 1 THEN 1
                         ELSE NULL end                                                                               AS total_selected_row
     FROM last_applied_shift
     WHERE TRUE
     QUALIFY (job_category_name = applied_preference)
          OR total_selected_row = 1)
   , last_seen_shift AS
    (SELECT DISTINCT eligible_matched_talent
                   , user_uuid
                   , rank()
                     over (PARTITION BY talent_uuid ORDER BY last_job_details_seen, job_details_seen_count desc)     AS rnk_shifts
                   , count(job_category_name) over (PARTITION BY eligible_matched_talent)                            AS cnt_shifts
                   , count(jac.job_uuid)
                     OVER (PARTITION BY eligible_matched_talent, job_category_name, matched_tag)                     AS no_jobs_seen
                   , djc.job_category_name
                   , matched_tag
                   , max(last_job_details_seen) over (PARTITION BY eligible_matched_talent)                          AS last_seen_job
     FROM talent_list tl
              LEFT JOIN dwh_db.dds.job_details_seen jac ON tl.user_uuid = jac.talent_uuid
              JOIN dwh_db.cds.fact_job fj ON jac.job_uuid = fj.job_uuid AND tl.matched_tag = fj.mandatory_include_tags
              JOIN dwh_db.cds.dim_job_category djc ON Fj.job_category_fk = djc.job_category_id
     WHERE TRUE
       AND last_job_details_seen >= dateadd('day', -60, current_date)
       AND last_job_details_seen <= dateadd('day', 1, current_date))
   , seen_preference as
    (SELECT DISTINCT eligible_matched_talent
                   , user_uuid
                   , cnt_shifts
                   , no_jobs_seen                                                                                    as seen_count
                   , dense_rank()
                     OVER (PARTITION BY eligible_matched_talent ORDER BY no_jobs_seen desc)                          AS ranking_by_cnt
                   , CASE WHEN cnt_shifts = rnk_shifts THEN job_category_name END                                    AS seen_preference
                   , job_category_name
                   , matched_tag
                   , last_seen_job
                   , CASE
                         WHEN count(user_uuid) OVER (PARTITION BY eligible_matched_talent) = 1 THEN 1
                         ELSE NULL end                                                                               AS total_selected_row
     FROM last_seen_shift
     WHERE TRUE
     QUALIFY (job_category_name = seen_preference)
          OR total_selected_row = 1)
   , revenue_gap_driven_preference as
    (select fs.business_region
          , dbr.matching_region_name
          , job_category_name
          , mandatory_include_tags
          , sum(ordered_revenue_value - booked_revenue_value) as unfulfilled_revenue
     from dwh_db.cds.fact_shift fs
              LEFT JOIN dwh_db.cds.fact_job fj on fs.job_fk = fj.job_id
              left join dwh_db.cds.dim_job_category djc on fj.job_category_fk = djc.job_category_id
              left join dwh_db.cds.dim_business_region dbr on fs.business_region = dbr.business_region_name
              inner join talent_list tl on dbr.matching_region_name = tl.matching_region_name
     where shift_dt between current_date and current_date + interval '3 day'
     group by 1, 2, 3, 4)
   , eligibility_preference as
    (select eligible_matched_talent,
            user_uuid,
            employment_city,
            tl.matching_region_name,
            job_category_name                                                      as eligible_preference,
            unfulfilled_revenue,
            rank() over (partition by user_uuid order by unfulfilled_revenue desc) as eligible_ranking
     from talent_list tl
              left join revenue_gap_driven_preference rgp on tl.matching_region_name = rgp.matching_region_name
     where unfulfilled_revenue > 0
     group by 1, 2, 3, 4, 5, 6
     qualify eligible_ranking = 1)
SELECT DISTINCT tl.eligible_matched_talent as talent_id
              , tl.user_uuid
              , tl.matching_region_name
              , tl.employment_city
              , CASE
                    WHEN working_preference = applied_preference THEN working_preference
                    WHEN (working_preference <> applied_preference OR working_preference IS NULL) AND
                         applied_preference IS NOT NULL THEN applied_preference
                    WHEN working_preference IS NOT NULL AND applied_preference IS NULL THEN working_preference
                    WHEN working_preference IS NULL AND applied_preference IS NULL AND seen_preference IS NOT NULL
                        THEN seen_preference
                    ELSE eligible_preference
    END                                    AS job_category_key
FROM talent_list tl
         LEFT JOIN worked_category a on tl.eligible_matched_talent = a.eligible_matched_talent
         LEFT JOIN applied_preference b ON tl.eligible_matched_talent = b.eligible_matched_talent
         LEFT JOIN seen_preference c ON tl.eligible_matched_talent = c.eligible_matched_talent
         LEFT JOIN eligibility_preference d on tl.eligible_matched_talent = d.eligible_matched_talent