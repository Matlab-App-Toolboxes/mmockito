classdef Mock < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    % General design: mockery is a cell array of tuples:
    %       (Invocation, result, numberOfCalls)
    % where numberOfCalls is the amount of times a given call can be
    % matched (accepting inf for infinite).
    
    properties
        mockery = {};
        mockeryLength = 0;
    end
    
    methods       
        function answer = subsref(obj, S)
            import mmockito.internal.*;

            if S(1).type ~= '.'
                ME = MException('mmockito:illegalCall', ...
                                'Must call a function on the mock object');
                throw(ME);
                % FIXME: this means arrays of mocks wouldn't work, there
                % must be a better way to have this check
                % Arrays also wouldn't work because substruct references
                % are hardcoded everywhere (ie. S(1).subs)
            end;

            if strcmp(S(1).subs, 'when')
                obj.when(S(2:end));
            elseif strcmp(S(1).subs, 'verify')
                % TODO: implement this
            else
                if length(S) > 1
                    % otherwise we get index exceeded errors due to the
                    % Invocation(S(1:2)) call
                    for i=1:obj.mockeryLength
                        if obj.mockery{i,3} > 0 && ...
                           obj.mockery{i,1}.matches(Invocation(S(1:2)))
                            res = obj.mockery{i,2}{1};
                            obj.mockery{i,3} = obj.mockery{i,3} - 1;
                            if isa(res, 'MException')
                                throw(res);
                            else
                                answer = res;
                                return;
                            end;
                        end;
                    end;
                end;

                answer = builtin('subsref', obj, S);
            end;
        end;
        
        function when(self, S)
            % substruct('.','when',
            %           '.','asdf',
            %           '()',{[5]},
            %           '.', 'thenReturn',
            %           '()', {[6]})
            import mmockito.internal.*;

            invmatcher = InvocationMatcher(Invocation(S(1:2)));

            % use index to handle multiple thenReturn statements
            ind = 3;
            % lastTimes is true if the last keyword was "times" -- it means
            % we shouldn't mock infinitely, only the given number of times
            lastTimes = false;
            while ind <= length(S)
                if strcmp(S(ind).subs, 'thenPass')
                    mockedValue = {true};
                elseif strcmp(S(ind).subs, 'thenReturn')
                    mockedValue = S(ind+1).subs;
                elseif strcmp(S(ind).subs, 'thenThrow')
                    if ~isa(S(ind+1).subs{1}, 'MException')
                        ME = MException('mmockito:illegalCall', ...
                        'Must use a MException object as argument to thenThrow.');
                        throw(ME);
                    end;
                    mockedValue = S(ind+1).subs;
                else
                    ME = MException('mmockito:illegalCall', ...
                    'After defining a function, must use either thenReturn, thenPass or thenThrow.');
                    throw(ME);
                end;

                ind = ind + 2;
                timesMocked = 1;
                lastTimes = false;
                % check for the "times" keyword
                if ind <= length(S) && strcmp(S(ind).subs, 'times')
                    timesMocked = S(ind+1).subs{1};
                    ind = ind + 2;
                    lastTimes = true;
                end;

                self.mockeryLength = self.mockeryLength + 1;
                self.mockery{self.mockeryLength, 1} = invmatcher;
                self.mockery{self.mockeryLength, 2} = mockedValue;
                self.mockery{self.mockeryLength, 3} = timesMocked;
            end;
            
            % the last result should be callable forever unless the keyword
            % chain ended with "times"
            if ~lastTimes
                self.mockery{self.mockeryLength, 3} = inf;
            end;
        end;
            
    end
    
end

