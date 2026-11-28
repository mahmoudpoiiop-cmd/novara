-- NOVARA update v2. Run ONCE in Supabase > SQL Editor > New query > Run.

-- 1) consent record + game scores
alter table public.profiles add column if not exists terms_accepted_at timestamptz;
alter table public.profiles add column if not exists terms_version int default 0;

create table if not exists public.game_scores (
  user_id uuid references public.profiles(id) on delete cascade,
  game text not null check (game in ('snake','tap')),
  score int not null default 0,
  updated_at timestamptz default now(),
  primary key (user_id, game)
);
alter table public.game_scores enable row level security;
drop policy if exists "scores read" on public.game_scores;
create policy "scores read" on public.game_scores for select to authenticated using (true);
drop policy if exists "scores write own" on public.game_scores;
create policy "scores write own" on public.game_scores for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 2) account deletion (conversations must not block it)
alter table public.conversations drop constraint if exists conversations_created_by_fkey;
alter table public.conversations add constraint conversations_created_by_fkey
  foreign key (created_by) references public.profiles(id) on delete set null;

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = auth.uid();
  delete from public.conversations c
   where not exists (select 1 from public.conversation_members m where m.conversation_id = c.id);
end $$;
revoke all on function public.delete_my_account() from public, anon;

-- 3) starter library (only if the books table is empty)
insert into public.books (title, category, body)
select * from (values
  ($t$ليلة الظلال$t$, $t$رعب$t$, $t$انقطعت الكهرباء عن القرية في منتصف الليل. أمسكت سلمى شمعة وخرجت لتتفقد الباب الخلفي.

سمعت خطوات خفيفة في الممر، خطوات تشبه خطواتها تماماً. توقفت، فتوقفت الخطوات. تقدمت، فتقدمت معها.

رفعت الشمعة ببطء نحو المرآة القديمة، فرأت نفسها تبتسم، وهي لم تبتسم بعد.

انطفأت الشمعة. ومن ذلك اليوم، لا تعرف سلمى أيّهما هي التي عادت إلى الغرفة.$t$),
  ($t$البيت المهجور$t$, $t$رعب$t$, $t$قال الجيران إن البيت في آخر الحارة مهجور منذ أربعين سنة، لكن النافذة العلوية كانت تضيء كل جمعة.

قرر كريم ورفاقه أن يكشفوا السر. دفعوا الباب الخشبي فانفتح بصرير طويل، وبدا الداخل نظيفاً كأن أحداً يسكنه.

على الطاولة وجدوا خمسة أكواب شاي ما زالت تتصاعد منها الأبخرة، وبجانبها ورقة مكتوب فيها: «تأخرتم يا أولاد، كنا ننتظركم».

أغلق الباب خلفهم من تلقاء نفسه.$t$),
  ($t$رسائل المطر$t$, $t$حب$t$, $t$كل يوم ممطر كانت ليلى تجد ورقة صغيرة تحت مظلتها عند محطة الباص، مكتوب فيها جملة دافئة بخط جميل.

لم تعرف من يكتبها، لكنها صارت تنتظر المطر بدل أن تخاف منه.

في اليوم الأخير من الشتاء لم تجد ورقة. وجدت شاباً يحمل مظلة مبللة ويقول بخجل: «نفدت مني الجمل، فجئت بنفسي».

ضحكت ليلى، وللمرة الأولى تمنت ألا يتوقف المطر.$t$),
  ($t$قلبان وقدر$t$, $t$حب$t$, $t$التقى آدم ومريم في مكتبة صغيرة، مدّا يديهما معاً إلى الكتاب الأخير على الرف.

قال آدم: «خذيه أنتِ». وقالت مريم: «نقرأه معاً، فصلاً لك وفصلاً لي».

مرّت سنوات، وانتهى ذلك الكتاب، لكنهما ما زالا يقرآن الفصل التالي من حكايتهما كل مساء، وكلما سألهما أحد عن السر قالا: لم نكمل شيئاً وحدنا بعد ذلك اليوم.$t$),
  ($t$سباق الصحراء$t$, $t$أكشن$t$, $t$انطلقت السيارات الأربع من نقطة البداية وسط عاصفة من الغبار. كان يزن يعلم أن محركه لن يصمد أكثر من ساعة.

عند الكثبان الكبيرة انقلبت سيارة المتصدر، فأبطأ يزن ليتأكد أن السائق بخير، ثم رفع له إبهامه وانطلق.

في آخر كيلومتر انطفأ محركه تماماً، فدفع السيارة بكتفيه نحو خط النهاية، والجمهور يصرخ باسمه.

لم يفز بالكأس، لكنه فاز بالاحترام الذي لا يُشترى.$t$),
  ($t$المطاردة الأخيرة$t$, $t$أكشن$t$, $t$قفز رامي من سطح إلى سطح، والطائرة المسيّرة تلاحقه فوق أضواء المدينة. كان في جيبه مفتاح الخزنة الذي يريده الجميع.

دخل زقاقاً ضيقاً، وانزلق تحت شاحنة متحركة، وخرج من الجهة الأخرى قبل أن تدرك المسيّرة أين اختفى.

وصل إلى الميناء، وسلّم المفتاح لضابطة تنتظره بابتسامة متعبة. قالت: «انتهت المطاردة». أجاب وهو يلهث: «بل بدأ الفصل الثاني».$t$)
) as v(title, category, body)
where not exists (select 1 from public.books);

-- 4) permissions for the new table and functions
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;
revoke execute on function public.delete_my_account() from anon;
