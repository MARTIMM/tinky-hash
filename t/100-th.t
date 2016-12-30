use v6.c;
use Test;
use Tinky::Hash;

#-------------------------------------------------------------------------------
subtest 'instantiate', {

  my Tinky::Hash $th .= new;
  is $th.^name, 'Tinky::Hash', 'type ok';
  ok $th.defined, 'object defined';
}

#-------------------------------------------------------------------------------
subtest 'setup', {

  my Tinky::Hash $th .= new(
    :config( %(
        :states([< a b c>]),
        :transitions( [
            %( :name<ab>, :from<a>, :to<b>),
            %( :name<ba>, :from<b>, :to<a>),
            %( :name<bc>, :from<b>, :to<c>),
            %( :name<ca>, :from<c>, :to<a>),
            %( :name<cb>, :from<c>, :to<b>),
          ]
        ),
        :workflow( {
            :name<wf1>,
            :initial-state<a>,
          }
        ),
      )
    )
  );

  diag 'Workflow wf1';
  $th.workflow('wf1');
  is $th.state.name, 'a', "starting state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, (<b>,), "next: {$th.next-states>>.name}";

  $th.go-state('b');
  is $th.state.name, 'b', "starting state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, <a c>, "next: {$th.next-states>>.name}";
}

#-------------------------------------------------------------------------------
subtest 'class setup', {

  class C1th is Tinky::Hash {

    submethod BUILD ( ) {

      self.from-hash(
        :config( %(
            :states([< a c q>]),
            :transitions( [
                %( :name<aq>, :from<a>, :to<q>),
                %( :name<qa>, :from<q>, :to<a>),
                %( :name<qc>, :from<q>, :to<c>),
                %( :name<ca>, :from<c>, :to<a>),
                %( :name<cq>, :from<c>, :to<q>),
              ]
            ),
            :workflow( {
                :name<wf2>,
                :initial-state<a>,
              }
            ),
          )
        )
      );
    }
  }

  my C1th $th .= new;

  diag 'Workflow wf1';
  $th.workflow('wf1');
  is $th.state.name, 'a', "starting state is '$th.state.name()'";
  is-deeply $th.next-states>>.name, [<b>], "next: {$th.next-states>>.name}";

  diag 'Workflow wf2';
  $th.workflow('wf2');
  $th.go-state('q');
  is $th.state.name, 'q', "state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, <a c>, "next: {$th.next-states>>.name}";

  diag 'Try workflow wf1';
  dies-ok {$th.workflow('wf1')},
          'Cannot switch when state is not known in other workflow, no next states';

  $th.go-state('c');
  is $th.state.name, 'c', "state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, <a q>, "next: {$th.next-states>>.name}";

  diag 'Workflow wf1';
  $th.workflow('wf1');
  is $th.state.name, 'c', "state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, <a b>, "next: {$th.next-states>>.name}";
}

#-------------------------------------------------------------------------------
subtest 'supplies1', {

  class C2th is Tinky::Hash {

    submethod BUILD ( ) {

      self.from-hash(
        :config( %(
            :states([< a q>]),
            :transitions( [
                %( :name<aq>, :from<a>, :to<q>),
                %( :name<qa>, :from<q>, :to<a>),
              ]
            ),
            :workflow( {
                :name<wf3>,
                :initial-state<a>,
                :transitions-tap('tr-method1'),
              }
            ),
          )
        )
      );
    }

    method tr-method1 ( $trans, $object) {
#say "M: ", self.^methods;
      say "Tr 1 '$object.^name()' '$trans.from.name()' ===>> '$trans.to.name()'";
    }
  }

  my C2th $th .= new;

  diag 'Workflow wf3';
  $th.workflow('wf3');
  is $th.state.name, 'a', "state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, (<q>,), "next: {$th.next-states>>.name}";

#  $th.aq;
  $th.go-state('q');
  is $th.state.name, 'q', "state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, (<a>,), "next: {$th.next-states>>.name}";
}

#-------------------------------------------------------------------------------
subtest 'supplies2', {

  class C3th is Tinky::Hash {

    submethod BUILD ( ) {

      self.from-hash(
        :config( %(
            :states([< a z q>]),
            :transitions( [
                { :name<az>, :from<a>, :to<z>},
                { :name<za>, :from<z>, :to<a>},
                { :name<zq>, :from<z>, :to<q>},
                { :name<qa>, :from<q>, :to<a>},
              ]
            ),
            :workflow( {
                :name<wf4>,
                :initial-state<a>,
                :transitions-tap<tr-method2>,
              }
            ),
            :taps(
              :states( {
                  :a( {
                      :leave<leave-a>
                    }
                  )
                }
              ),
              :transitions( {
                  :zq<trans-zq>
                }
              ),
              :transitions-global<tr-method2>
            ),
          )
        )
      );
    }

    method tr-method2 ( $trans, $object) {
      say "Tr 2 '$object.^name()' '$trans.from.name()' ===>> '$trans.to.name()'";
    }
  }

  my C3th $th .= new;

  diag 'Workflow wf4';
  $th.workflow('wf4');
  is $th.state.name, 'a', "state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, (<z>,), "next: {$th.next-states>>.name}";

  $th.go-state('z');
  is $th.state.name, 'z', "state is '$th.state.name()'";
  is-deeply $th.next-states>>.name.sort, (<a q>), "next: {$th.next-states>>.name}";

  $th.go-state('q');
  diag 'Workflow wf3, transition supply from previous workflow';
  $th.workflow('wf3');
  $th.go-state('a');
}

#-------------------------------------------------------------------------------
done-testing;